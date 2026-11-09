import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recurring_transaction.dart';

class RecurringTransactionHiveStorage {
  static const String _recurringTransactionBoxName = 'recurring_transactions';
  static const String _deletedRecurringBoxName = 'deleted_recurring_transactions';
  static Box<RecurringTransaction>? _recurringTransactionBox;
  static Box<String>? _deletedBox;

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

    if (_deletedBox == null || !_deletedBox!.isOpen) {
      _deletedBox = await Hive.openBox<String>(_deletedRecurringBoxName);
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

  /// Track a deleted recurring transaction ID for cloud sync
  static Future<void> _trackDeletedRecurring(String recurringId, String userId) async {
    if (_deletedBox == null || !_deletedBox!.isOpen) {
      _deletedBox = await Hive.openBox<String>(_deletedRecurringBoxName);
    }
    await _deletedBox!.put(recurringId, userId);
  }

  /// Get pending deleted recurring transaction IDs for current user
  static List<String> getPendingDeletedIds() {
    if (_deletedBox == null || !_deletedBox!.isOpen) return [];
    final userId = _getUserId();
    final List<String> result = [];
    for (final entry in _deletedBox!.toMap().entries) {
      if (entry.value == userId) {
        result.add(entry.key.toString());
      }
    }
    return result;
  }

  /// Clear synced deleted recurring transaction IDs
  static Future<void> clearDeletedIds(List<String> ids) async {
    if (_deletedBox == null || !_deletedBox!.isOpen) return;
    for (final id in ids) {
      await _deletedBox!.delete(id);
    }
  }

  /// Delete a recurring transaction from Hive
  static Future<void> deleteRecurringTransaction(String id) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    final recurring = _recurringTransactionBox!.get(id);
    final userId = recurring?.userId ?? _getUserId();
    await _trackDeletedRecurring(id, userId);
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

  /// Mark multiple recurring transactions as synced using atomic putAll
  static Future<void> markMultipleAsSynced(List<String> ids) async {
    await init();
    if (_recurringTransactionBox == null) {
      throw Exception('RecurringTransaction box not initialized');
    }
    
    final Map<String, RecurringTransaction> updates = {};
    for (final id in ids) {
      final recurring = _recurringTransactionBox!.get(id);
      if (recurring != null) {
        updates[id] = recurring.copyWith(isSynced: true);
      }
    }
    if (updates.isNotEmpty) {
      await _recurringTransactionBox!.putAll(updates);
    }
  }

  /// Get sync statistics
  static Map<String, int> getSyncStatistics() {
    if (_recurringTransactionBox == null || !_recurringTransactionBox!.isOpen) {
      return {'total': 0, 'synced': 0, 'unsynced': 0, 'pendingDeletions': 0};
    }
    
    final userId = _getUserId();
    final allRecurring = _recurringTransactionBox!.values
        .where((recurring) => recurring.userId == userId)
        .toList();
    
    final synced = allRecurring.where((recurring) => recurring.isSynced).length;
    final unsynced = allRecurring.length - synced;
    final pendingDeletions = getPendingDeletedIds().length;
    
    return {
      'total': allRecurring.length,
      'synced': synced,
      'unsynced': unsynced,
      'pendingDeletions': pendingDeletions,
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

