import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../common/account_hive_storage.dart';

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
    
    // Add to local list
    _accounts.add(account);
    
    // Save to Hive
    await AccountHiveStorage.saveAccount(account);
    
    notifyListeners();
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

      // 1. Sync unsynced accounts (new/updated) using atomic WriteBatch
      if (unsyncedAccounts.isNotEmpty) {
        const batchSize = 400;
        for (var i = 0; i < unsyncedAccounts.length; i += batchSize) {
          final end = (i + batchSize < unsyncedAccounts.length)
              ? i + batchSize
              : unsyncedAccounts.length;
          final chunk = unsyncedAccounts.sublist(i, end);
          final batch = firestore.batch();

          for (final account in chunk) {
            final docRef = firestore
                .collection('accounts')
                .doc(userId)
                .collection('userAccounts')
                .doc(account.id);
            batch.set(docRef, account.toFirestoreMap());
          }

          await batch.commit();
          final chunkIds = chunk.map((a) => a.id).toList();
          await AccountHiveStorage.markMultipleAsSynced(chunkIds);
          debugPrint('Synced batch of ${chunk.length} account(s) to Firestore');
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

  /// Sync deletions: Delete pending deleted accounts from Firestore without querying all documents
  Future<void> _syncAccountDeletions() async {
    try {
      final idsToDelete = AccountHiveStorage.getPendingDeletedIds();
      if (idsToDelete.isEmpty) return;

      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      const batchSize = 400;
      for (var i = 0; i < idsToDelete.length; i += batchSize) {
        final end = (i + batchSize < idsToDelete.length) ? i + batchSize : idsToDelete.length;
        final chunk = idsToDelete.sublist(i, end);
        final batch = firestore.batch();

        for (final accountId in chunk) {
          if (accountId == 'cash') continue; // Safety guard: never delete cash account
          final docRef = firestore
              .collection('accounts')
              .doc(userId)
              .collection('userAccounts')
              .doc(accountId);
          batch.delete(docRef);
        }

        await batch.commit();
        await AccountHiveStorage.clearDeletedIds(chunk);
        debugPrint('Synced ${chunk.length} account deletion(s) to Firestore');
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

