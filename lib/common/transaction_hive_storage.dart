import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/hive_transaction.dart';

class TransactionHiveStorage {
  static const String _transactionBoxName = 'transactions';
  static Box<HiveTransaction>? _transactionBox;

  /// Initialize transaction box
  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(1)) { // 1 is your typeId for HiveTransaction
      Hive.registerAdapter(HiveTransactionAdapter());
    }

    if (_transactionBox == null || !_transactionBox!.isOpen) {
      _transactionBox = await Hive.openBox<HiveTransaction>(_transactionBoxName);
    }
  }


  /// Get current user ID
  static String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  /// Save transaction to Hive
  static Future<void> saveTransaction(HiveTransaction transaction) async {
    if (_transactionBox == null) {
      await init();
    }
    await _transactionBox!.put(transaction.id, transaction);
  }

  /// Get all transactions for current user
  static List<HiveTransaction> getAllTransactions() {
    if (_transactionBox == null) return [];
    
    final userId = _getUserId();
    return _transactionBox!.values
        .where((transaction) => transaction.userId == userId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Get unsynced transactions
  static List<HiveTransaction> getUnsyncedTransactions() {
    if (_transactionBox == null) return [];
    
    final userId = _getUserId();
    return _transactionBox!.values
        .where((transaction) => 
            transaction.userId == userId && !transaction.isSynced)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Sort by creation date ascending
  }

  /// Get synced transactions
  static List<HiveTransaction> getSyncedTransactions() {
    if (_transactionBox == null) return [];
    
    final userId = _getUserId();
    return _transactionBox!.values
        .where((transaction) => 
            transaction.userId == userId && transaction.isSynced)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Get transactions in date range
  static List<HiveTransaction> getTransactionsInRange(DateTime start, DateTime end) {
    if (_transactionBox == null) return [];
    
    final userId = _getUserId();
    return _transactionBox!.values
        .where((transaction) => 
            transaction.userId == userId &&
            !transaction.date.isBefore(start) &&
            !transaction.date.isAfter(end))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
  }

  /// Update transaction
  static Future<void> updateTransaction(HiveTransaction transaction) async {
    if (_transactionBox == null) {
      await init();
    }
    await _transactionBox!.put(transaction.id, transaction);
  }

  /// Delete transaction
  static Future<void> deleteTransaction(String transactionId) async {
    if (_transactionBox == null) return;
    await _transactionBox!.delete(transactionId);
  }

  /// Mark transaction as synced
  static Future<void> markAsSynced(String transactionId) async {
    if (_transactionBox == null) return;
    
    final transaction = _transactionBox!.get(transactionId);
    if (transaction != null) {
      final updatedTransaction = transaction.copyWith(isSynced: true);
      await _transactionBox!.put(transactionId, updatedTransaction);
    }
  }

  /// Mark multiple transactions as synced
  static Future<void> markMultipleAsSynced(List<String> transactionIds) async {
    if (_transactionBox == null) return;
    
    for (final id in transactionIds) {
      final transaction = _transactionBox!.get(id);
      if (transaction != null) {
        final updatedTransaction = transaction.copyWith(isSynced: true);
        await _transactionBox!.put(id, updatedTransaction);
      }
    }
  }

  /// Get sync statistics
  static Map<String, int> getSyncStatistics() {
    if (_transactionBox == null) return {'total': 0, 'synced': 0, 'unsynced': 0};
    
    final userId = _getUserId();
    final userTransactions = _transactionBox!.values
        .where((transaction) => transaction.userId == userId)
        .toList();
    
    return {
      'total': userTransactions.length,
      'synced': userTransactions.where((t) => t.isSynced).length,
      'unsynced': userTransactions.where((t) => !t.isSynced).length,
    };
  }

  /// Clear all transactions for current user
  static Future<void> clearUserTransactions() async {
    if (_transactionBox == null) return;
    
    final userId = _getUserId();
    final userTransactionIds = _transactionBox!.values
        .where((transaction) => transaction.userId == userId)
        .map((transaction) => transaction.id)
        .toList();
    
    for (final id in userTransactionIds) {
      await _transactionBox!.delete(id);
    }
  }

  /// Clear all transactions (for logout)
  static Future<void> clearAllTransactions() async {
    if (_transactionBox == null) return;
    await _transactionBox!.clear();
  }

  /// Close the transaction box
  static Future<void> close() async {
    await _transactionBox?.close();
  }
}
