import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../common/account_hive_storage.dart';
import '../common/premium_constants.dart';
import '../services/premium_service.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider();

  final List<Account> _accounts = <Account>[];
  bool _initialized = false;

  List<Account> get accounts => List.unmodifiable(_accounts);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await AccountHiveStorage.init();
    
    // Ensure Cash account exists before loading
    await AccountHiveStorage.initializeDefaultCashAccount();
    
    await _loadFromHive();
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    final hiveAccounts = AccountHiveStorage.getAllAccounts();
    _accounts.clear();
    _accounts.addAll(hiveAccounts);
  }

  String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  Future<void> addAccount(Account account) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }
    
    // Count accounts excluding the default "cash" account
    final nonCashAccounts = _accounts.where((a) => a.id != 'cash').length;
    
    // Check account limit based on premium status
    if (PremiumService.instance.isPremium) {
      // Premium users have a limit of 2 accounts
      if (nonCashAccounts >= PremiumConstants.PREMIUM_MAX_ACCOUNTS) {
        throw Exception('Account limit reached. Premium users can have up to ${PremiumConstants.PREMIUM_MAX_ACCOUNTS} accounts.');
      }
    } else {
      // Free users have a limit of 3 accounts
      if (nonCashAccounts >= PremiumConstants.FREE_MAX_ACCOUNTS) {
        throw Exception('Account limit reached. Upgrade to Premium for ${PremiumConstants.PREMIUM_MAX_ACCOUNTS} accounts.');
      }
    }
    
    // Add to local list
    _accounts.add(account);
    
    // Save to Hive
    await AccountHiveStorage.saveAccount(account);
    
    notifyListeners();
  }

  /// Get current account count (excluding cash)
  int getAccountCount() {
    return _accounts.where((a) => a.id != 'cash').length;
  }

  /// Check if user can add more accounts
  bool canAddAccount() {
    final accountCount = getAccountCount();
    if (PremiumService.instance.isPremium) {
      return accountCount < PremiumConstants.PREMIUM_MAX_ACCOUNTS;
    }
    return accountCount < PremiumConstants.FREE_MAX_ACCOUNTS;
  }

  Future<void> updateAccount(Account account) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }
    
    final idx = _accounts.indexWhere((e) => e.id == account.id);
    if (idx != -1) {
      _accounts[idx] = account;
      
      // Update in Hive
      await AccountHiveStorage.updateAccount(account);
      
      notifyListeners();
    }
  }

  Future<void> removeAccount(String id) async {
    // Prevent deletion of Cash account
    if (id == 'cash') {
      debugPrint('Cannot delete Cash account');
      return;
    }
    
    _accounts.removeWhere((e) => e.id == id);
    await AccountHiveStorage.deleteAccount(id);
    notifyListeners();
  }

  Account? getAccount(String id) {
    try {
      return _accounts.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Account> getAllAccounts() {
    return List<Account>.from(_accounts);
  }

  // Sync related methods
  List<Account> getUnsyncedAccounts() {
    return AccountHiveStorage.getUnsyncedAccounts();
  }

  Map<String, int> getSyncStatistics() {
    return AccountHiveStorage.getSyncStatistics();
  }

  Future<bool> syncAccountsToFirestore() async {
    try {
      final unsyncedAccounts = getUnsyncedAccounts();
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // 1. Sync unsynced accounts (new/updated)
      if (unsyncedAccounts.isNotEmpty) {
      for (final account in unsyncedAccounts) {
        await firestore
            .collection('accounts')
            .doc(userId) // document for the user
            .collection('userAccounts') // subcollection for this user's accounts
            .doc(account.id)
            .set(account.toFirestoreMap());

        // Mark as synced in Hive
        await AccountHiveStorage.markAsSynced(account.id);
      }
      }

      // 2. Sync deletions - delete accounts from Firestore that don't exist locally
      await _syncAccountDeletions();

      // Refresh local data
      await _loadFromHive();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error syncing accounts: $e');
      return false;
    }
  }

  /// Sync deletions: Delete accounts from Firestore that don't exist locally
  Future<void> _syncAccountDeletions() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Get all local account IDs (excluding cash which shouldn't be deleted)
      final localAccounts = AccountHiveStorage.getAllAccounts();
      final localAccountIds = localAccounts.map((a) => a.id).toSet();

      // Get all account IDs from Firestore
      final firestoreSnapshot = await firestore
          .collection('accounts')
          .doc(userId)
          .collection('userAccounts')
          .get();

      // Find accounts in Firestore that don't exist locally
      final accountsToDelete = <String>[];
      for (final doc in firestoreSnapshot.docs) {
        // Don't delete cash account even if it's missing locally
        if (doc.id != 'cash' && !localAccountIds.contains(doc.id)) {
          accountsToDelete.add(doc.id);
        }
      }

      // Delete orphaned accounts from Firestore
      for (final accountId in accountsToDelete) {
        await firestore
            .collection('accounts')
            .doc(userId)
            .collection('userAccounts')
            .doc(accountId)
            .delete();
        debugPrint('Deleted account $accountId from Firestore');
      }

      if (accountsToDelete.isNotEmpty) {
        debugPrint('Synced ${accountsToDelete.length} account deletion(s) to Firestore');
      }
    } catch (e) {
      debugPrint('Error syncing account deletions: $e');
    }
  }

  Future<void> loadAccountsFromFirestore() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Fetch accounts from Firestore
      final accountsSnapshot = await firestore
          .collection('accounts')
          .doc(userId)
          .collection('userAccounts')
          .get();

      if (accountsSnapshot.docs.isNotEmpty) {
        for (final doc in accountsSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to Account
          final account = Account.fromFirestoreMap(data, doc.id);

          // Save to Hive (will overwrite local if exists)
          await AccountHiveStorage.saveAccount(account);
        }
        debugPrint("Accounts synced from Firestore to Hive.");
      } else {
        debugPrint("No accounts found in Firestore for this user.");
      }

      // Ensure Cash account exists (even if synced from Firestore)
      await AccountHiveStorage.initializeDefaultCashAccount();

      // Refresh local data
      await _loadFromHive();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading accounts from Firestore: $e');
    }
  }

  Future<void> refreshFromHive() async {
    await _loadFromHive();
    notifyListeners();
  }

  /// Reset and reinitialize the provider (for logout/login)
  Future<void> resetAndInitialize() async {
    _accounts.clear();
    _initialized = false;
    await initialize();
  }
}

