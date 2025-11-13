import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import '../models/hive_transaction.dart';
import '../common/transaction_hive_storage.dart';

class TransactionProvider extends ChangeNotifier {
  TransactionProvider();

  final List<TransactionItem> _items = <TransactionItem>[];
  bool _initialized = false;

  List<TransactionItem> get items => List.unmodifiable(_items);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await TransactionHiveStorage.init();
    await _loadFromHive();
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    final hiveTransactions = TransactionHiveStorage.getAllTransactions();
    _items.clear();
    
    for (final hiveTransaction in hiveTransactions) {
      final transactionItem = TransactionItem(
        id: hiveTransaction.id,
        title: hiveTransaction.title,
        amount: hiveTransaction.amount,
        type: hiveTransaction.type == 'income' ? TransactionType.income : TransactionType.expense,
        date: hiveTransaction.date,
        category: hiveTransaction.category,
        note: hiveTransaction.note,
        accountId: hiveTransaction.accountId,
        recurringTransactionId: hiveTransaction.recurringTransactionId,
      );
      _items.add(transactionItem);
    }
  }

  String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  Future<void> add(TransactionItem item) async {
    // Add to local list
    _items.add(item);
    
    // Save to Hive
    final hiveTransaction = HiveTransaction.fromTransactionItemData(
      item.toJson(),
      _getUserId(),
    );
    await TransactionHiveStorage.saveTransaction(hiveTransaction);
    
    notifyListeners();
  }

  Future<void> update(TransactionItem item) async {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      _items[idx] = item;
      
      // Update in Hive
      final hiveTransaction = HiveTransaction.fromTransactionItemData(
        item.toJson(),
        _getUserId(),
      );
      await TransactionHiveStorage.updateTransaction(hiveTransaction);
      
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    _items.removeWhere((e) => e.id == id);
    await TransactionHiveStorage.deleteTransaction(id);
    notifyListeners();
  }

  double get totalIncome => _items
      .where((e) => e.type == TransactionType.income)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalExpense => _items
      .where((e) => e.type == TransactionType.expense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get balance => totalIncome - totalExpense;

  List<TransactionItem> inRange(DateTime start, DateTime end) {
    final hiveTransactions = TransactionHiveStorage.getTransactionsInRange(start, end);
    final filteredItems = <TransactionItem>[];
    
    for (final hiveTransaction in hiveTransactions) {
      final transactionItem = TransactionItem(
        id: hiveTransaction.id,
        title: hiveTransaction.title,
        amount: hiveTransaction.amount,
        type: hiveTransaction.type == 'income' ? TransactionType.income : TransactionType.expense,
        date: hiveTransaction.date,
        category: hiveTransaction.category,
        note: hiveTransaction.note,
        accountId: hiveTransaction.accountId,
        recurringTransactionId: hiveTransaction.recurringTransactionId,
      );
      filteredItems.add(transactionItem);
    }
    
    return filteredItems;
  }

  /// Get transactions for a specific account
  List<TransactionItem> getTransactionsByAccount(String accountId) {
    return _items.where((e) => e.accountId == accountId).toList();
  }

  /// Get transactions for a specific account in date range
  List<TransactionItem> getTransactionsByAccountInRange(String accountId, DateTime start, DateTime end) {
    final allInRange = inRange(start, end);
    return allInRange.where((e) => e.accountId == accountId).toList();
  }

  /// Get account balance (income - expense) for a specific account
  double getAccountBalance(String accountId) {
    final accountTransactions = getTransactionsByAccount(accountId);
    final income = accountTransactions
        .where((e) => e.type == TransactionType.income)
        .fold(0.0, (sum, e) => sum + e.amount);
    final expense = accountTransactions
        .where((e) => e.type == TransactionType.expense)
        .fold(0.0, (sum, e) => sum + e.amount);
    return income - expense;
  }

  /// Get account income for a specific account
  double getAccountIncome(String accountId) {
    return getTransactionsByAccount(accountId)
        .where((e) => e.type == TransactionType.income)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Get account expense for a specific account
  double getAccountExpense(String accountId) {
    return getTransactionsByAccount(accountId)
        .where((e) => e.type == TransactionType.expense)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<TransactionItem> getAllTransactions() {
    return List<TransactionItem>.from(_items);
  }

  // Sync related methods
  List<HiveTransaction> getUnsyncedTransactions() {
    return TransactionHiveStorage.getUnsyncedTransactions();
  }

  Map<String, int> getSyncStatistics() {
    return TransactionHiveStorage.getSyncStatistics();
  }

  Future<bool> syncTransactionsToFirestore() async {
    try {
      final unsyncedTransactions = getUnsyncedTransactions();
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // 1. Sync unsynced transactions (new/updated)
      if (unsyncedTransactions.isNotEmpty) {
      for (final transaction in unsyncedTransactions) {
        await firestore
            .collection('transactions')
            .doc(userId) // document for the user
            .collection('userTransactions') // subcollection for this user's transactions
            .doc(transaction.id)
            .set(transaction.toFirestoreMap());

        // Mark as synced in Hive
        await TransactionHiveStorage.markAsSynced(transaction.id);
      }
      }

      // 2. Sync deletions - delete transactions from Firestore that don't exist locally
      await _syncTransactionDeletions();

      // Refresh local data
      await _loadFromHive();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error syncing transactions: $e');
      return false;
    }
  }

  /// Sync deletions: Delete transactions from Firestore that don't exist locally
  Future<void> _syncTransactionDeletions() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Get all local transaction IDs
      final localTransactions = TransactionHiveStorage.getAllTransactions();
      final localTransactionIds = localTransactions.map((t) => t.id).toSet();

      // Get all transaction IDs from Firestore
      final firestoreSnapshot = await firestore
          .collection('transactions')
          .doc(userId)
          .collection('userTransactions')
          .get();

      // Find transactions in Firestore that don't exist locally
      final transactionsToDelete = <String>[];
      for (final doc in firestoreSnapshot.docs) {
        if (!localTransactionIds.contains(doc.id)) {
          transactionsToDelete.add(doc.id);
        }
      }

      // Delete orphaned transactions from Firestore
      for (final transactionId in transactionsToDelete) {
        await firestore
            .collection('transactions')
            .doc(userId)
            .collection('userTransactions')
            .doc(transactionId)
            .delete();
        debugPrint('Deleted transaction $transactionId from Firestore');
      }

      if (transactionsToDelete.isNotEmpty) {
        debugPrint('Synced ${transactionsToDelete.length} transaction deletion(s) to Firestore');
      }
    } catch (e) {
      debugPrint('Error syncing transaction deletions: $e');
    }
  }

  //To fetch data for all user
  // final snapshot = await FirebaseFirestore.instance
  //     .collection('transactions')
  //     .doc(userId)
  //     .collection('userTransactions')
  //     .get();


  Future<void> refreshFromHive() async {
    await _loadFromHive();
    notifyListeners();
  }

  /// Reset and reinitialize the provider (for logout/login)
  Future<void> resetAndInitialize() async {
    _items.clear();
    _initialized = false;
    await initialize();
  }
}

