import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account.dart';

class AccountHiveStorage {
  static const String _accountBoxName = 'accounts';
  static Box<Account>? _accountBox;

  /// Initialize account box
  static Future<void> init() async {
    // Always register adapter first to ensure it's available
    if (!Hive.isAdapterRegistered(3)) {
      try {
        // Register the AccountAdapter
        // Note: AccountAdapter is defined in account.g.dart which is a part of account.dart
        Hive.registerAdapter(AccountAdapter());
        debugPrint('AccountAdapter registered successfully with typeId: 3');
      } catch (e) {
        debugPrint('Error registering AccountAdapter: $e');
        rethrow;
      }
    } else {
      debugPrint('AccountAdapter already registered');
    }

    // Close existing box if open (to ensure adapter is used)
    if (_accountBox != null && _accountBox!.isOpen) {
      await _accountBox!.close();
      _accountBox = null;
    }

    // Open the box with the registered adapter
    if (_accountBox == null || !_accountBox!.isOpen) {
      try {
        _accountBox = await Hive.openBox<Account>(_accountBoxName);
        debugPrint('Account box opened successfully');
      } catch (e) {
        debugPrint('Error opening account box: $e');
        debugPrint('Adapter registered: ${Hive.isAdapterRegistered(3)}');
        rethrow;
      }
    }
  }

  /// Get current user ID
  static String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  /// Save account to Hive
  static Future<void> saveAccount(Account account) async {
    // Ensure adapter is registered
    if (!Hive.isAdapterRegistered(3)) {
      debugPrint('Adapter not registered, registering now...');
      Hive.registerAdapter(AccountAdapter());
    }
    
    if (_accountBox == null) {
      await init();
    }
    
    try {
      await _accountBox!.put(account.id, account);
      debugPrint('Account saved successfully: ${account.name}');
    } catch (e) {
      debugPrint('Error saving account: $e');
      debugPrint('Adapter registered: ${Hive.isAdapterRegistered(3)}');
      rethrow;
    }
  }

  /// Get all accounts for current user
  static List<Account> getAllAccounts() {
    if (_accountBox == null) return [];
    
    final userId = _getUserId();
    final accounts = _accountBox!.values
        .where((account) => account.userId == userId)
        .toList();
    
    // Sort: Cash first, then alphabetically
    accounts.sort((a, b) {
      if (a.id == 'cash') return -1;
      if (b.id == 'cash') return 1;
      return a.name.compareTo(b.name);
    });
    
    return accounts;
  }

  /// Get account by ID
  static Account? getAccount(String accountId) {
    if (_accountBox == null) return null;
    return _accountBox!.get(accountId);
  }

  /// Get unsynced accounts
  static List<Account> getUnsyncedAccounts() {
    if (_accountBox == null) return [];
    
    final userId = _getUserId();
    return _accountBox!.values
        .where((account) => account.userId == userId && !account.isSynced)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Sort by creation date ascending
  }

  /// Update account
  static Future<void> updateAccount(Account account) async {
    if (_accountBox == null) {
      await init();
    }
    await _accountBox!.put(account.id, account);
  }

  /// Delete account
  static Future<void> deleteAccount(String accountId) async {
    if (_accountBox == null) return;
    await _accountBox!.delete(accountId);
  }

  /// Mark account as synced
  static Future<void> markAsSynced(String accountId) async {
    if (_accountBox == null) return;
    
    final account = _accountBox!.get(accountId);
    if (account != null) {
      final updatedAccount = account.copyWith(isSynced: true);
      await _accountBox!.put(accountId, updatedAccount);
    }
  }

  /// Get sync statistics
  static Map<String, int> getSyncStatistics() {
    if (_accountBox == null) return {'total': 0, 'synced': 0, 'unsynced': 0};
    
    final userId = _getUserId();
    final userAccounts = _accountBox!.values
        .where((account) => account.userId == userId)
        .toList();
    
    return {
      'total': userAccounts.length,
      'synced': userAccounts.where((a) => a.isSynced).length,
      'unsynced': userAccounts.where((a) => !a.isSynced).length,
    };
  }

  /// Initialize default Cash account if it doesn't exist
  static Future<void> initializeDefaultCashAccount() async {
    if (_accountBox == null) {
      await init();
    }

    final userId = _getUserId();
    final cashAccountId = 'cash';
    
    // Check if Cash account already exists
    final existingAccount = _accountBox!.get(cashAccountId);
    if (existingAccount != null && existingAccount.userId == userId) {
      return; // Cash account already exists
    }

    // Create default Cash account
    final cashAccount = Account(
      id: cashAccountId,
      name: 'Cash',
      balance: 0.0,
      createdAt: DateTime.now(),
      userId: userId,
      isSynced: false, // Will be synced later
    );

    await _accountBox!.put(cashAccountId, cashAccount);
  }

  /// Clear all accounts for current user
  static Future<void> clearUserAccounts() async {
    if (_accountBox == null) return;
    
    final userId = _getUserId();
    final userAccountIds = _accountBox!.values
        .where((account) => account.userId == userId)
        .map((account) => account.id)
        .toList();
    
    for (final id in userAccountIds) {
      await _accountBox!.delete(id);
    }
  }

  /// Clear all accounts (for logout)
  static Future<void> clearAllAccounts() async {
    if (_accountBox == null) return;
    await _accountBox!.clear();
  }

  /// Close the account box
  static Future<void> close() async {
    await _accountBox?.close();
  }
}

