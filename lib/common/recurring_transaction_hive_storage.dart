import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction.dart';

class RecurringTransactionHiveStorage {
  static const String _recurringTransactionBoxName = 'recurring_transactions';
  static Box<RecurringTransaction>? _recurringTransactionBox;

  /// Initialize recurring transaction box
  static Future<void> init() async {
    // Register RecurringFrequency enum adapter first (typeId: 8)
    if (!Hive.isAdapterRegistered(8)) {
      try {
        Hive.registerAdapter(RecurringFrequencyAdapter());
        debugPrint('RecurringFrequencyAdapter registered successfully with typeId: 8');
      } catch (e) {
        debugPrint('Error registering RecurringFrequencyAdapter: $e');
        rethrow;
      }
    }
    
    // Register RecurringTransaction adapter (typeId: 9)
    if (!Hive.isAdapterRegistered(9)) {
      try {
        Hive.registerAdapter(RecurringTransactionAdapter());
        debugPrint('RecurringTransactionAdapter registered successfully with typeId: 9');
      } catch (e) {
        debugPrint('Error registering RecurringTransactionAdapter: $e');
        rethrow;
      }
    } else {
      debugPrint('RecurringTransactionAdapter already registered');
    }

    // Close existing box if open
    if (_recurringTransactionBox != null && _recurringTransactionBox!.isOpen) {
      await _recurringTransactionBox!.close();
      _recurringTransactionBox = null;
    }

    // Open the box
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      try {
        _recurringTransactionBox = await Hive.openBox<RecurringTransaction>(_recurringTransactionBoxName);
        debugPrint('RecurringTransaction box opened successfully');
      } catch (e) {
        debugPrint('Error opening recurring transaction box: $e');
        rethrow;
      }
    }
  }

  /// Get current user ID
  static String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  /// Save a recurring transaction to Hive
  static Future<void> saveRecurringTransaction(RecurringTransaction recurringTransaction) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    final recurringWithUserId = recurringTransaction.copyWith(userId: _getUserId());
    await _recurringTransactionBox!.put(recurringWithUserId.id, recurringWithUserId);
    debugPrint('RecurringTransaction saved: ${recurringWithUserId.id}');
  }

  /// Update a recurring transaction in Hive
  static Future<void> updateRecurringTransaction(RecurringTransaction recurringTransaction) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    final recurringWithUserId = recurringTransaction.copyWith(userId: _getUserId());
    await _recurringTransactionBox!.put(recurringWithUserId.id, recurringWithUserId);
    debugPrint('RecurringTransaction updated: ${recurringWithUserId.id}');
  }

  /// Delete a recurring transaction from Hive
  static Future<void> deleteRecurringTransaction(String id) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    await _recurringTransactionBox!.delete(id);
    debugPrint('RecurringTransaction deleted: $id');
  }

  /// Get a recurring transaction by ID
  static RecurringTransaction? getRecurringTransaction(String id) {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return null;
    }
    return _recurringTransactionBox!.get(id);
  }

  /// Get all recurring transactions for current user
  static List<RecurringTransaction> getAllRecurringTransactions() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _recurringTransactionBox!.values
        .where((recurring) => recurring.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Get active recurring transactions
  static List<RecurringTransaction> getActiveRecurringTransactions() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _recurringTransactionBox!.values
        .where((recurring) => 
            recurring.userId == userId && 
            recurring.isActive && 
            !recurring.hasEnded)
        .toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence)); // Next occurrence first
  }

  /// Get inactive recurring transactions
  static List<RecurringTransaction> getInactiveRecurringTransactions() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _recurringTransactionBox!.values
        .where((recurring) => 
            recurring.userId == userId && 
            (!recurring.isActive || recurring.hasEnded))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Get recurring transactions that are due (nextOccurrence <= today)
  static List<RecurringTransaction> getDueRecurringTransactions() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _recurringTransactionBox!.values
        .where((recurring) => 
            recurring.userId == userId && 
            recurring.isActive && 
            !recurring.hasEnded &&
            recurring.isDue)
        .toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
  }

  /// Get unsynced recurring transactions
  static List<RecurringTransaction> getUnsyncedRecurringTransactions() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _recurringTransactionBox!.values
        .where((recurring) => 
            recurring.userId == userId && 
            !recurring.isSynced)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Mark a recurring transaction as synced
  static Future<void> markAsSynced(String id) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    final recurring = _recurringTransactionBox!.get(id);
    if (recurring != null) {
      final syncedRecurring = recurring.copyWith(isSynced: true);
      await _recurringTransactionBox!.put(id, syncedRecurring);
      debugPrint('RecurringTransaction marked as synced: $id');
    }
  }

  /// Get sync statistics
  static Map<String, int> getSyncStatistics() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return {'total': 0, 'synced': 0, 'unsynced': 0};
    }
    
    final userId = _getUserId();
    final allRecurring = _recurringTransactionBox!.values
        .where((recurring) => recurring.userId == userId)
        .toList();
    
    final synced = allRecurring.where((recurring) => recurring.isSynced).length;
    final unsynced = allRecurring.length - synced;
    
    return {
      'total': allRecurring.length,
      'synced': synced,
      'unsynced': unsynced,
    };
  }

  /// Clear all recurring transactions (for logout/data cleanup)
  static Future<void> clearAllRecurringTransactions() async {
    if (_recurringTransactionBox != null && _recurringTransactionBox!.isOpen) {
      await _recurringTransactionBox!.clear();
      debugPrint('All recurring transactions cleared');
    }
  }
}

