import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/recurring_transaction.dart';
import '../common/recurring_transaction_hive_storage.dart';
import 'transaction_provider.dart';
import '../models.dart';

class RecurringTransactionProvider extends ChangeNotifier {
  RecurringTransactionProvider();

  final List<RecurringTransaction> _recurringTransactions = <RecurringTransaction>[];
  bool _initialized = false;

  List<RecurringTransaction> get recurringTransactions => List.unmodifiable(_recurringTransactions);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await RecurringTransactionHiveStorage.init();
    await _loadFromHive();
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    final hiveRecurring = RecurringTransactionHiveStorage.getAllRecurringTransactions();
    _recurringTransactions.clear();
    _recurringTransactions.addAll(hiveRecurring);
  }

  String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  Future<void> addRecurringTransaction(RecurringTransaction recurringTransaction) async {
    if (!_initialized) {
      await initialize();
    }
    
    _recurringTransactions.add(recurringTransaction);
    await RecurringTransactionHiveStorage.saveRecurringTransaction(recurringTransaction);
    
    notifyListeners();
  }

  Future<void> updateRecurringTransaction(
    RecurringTransaction recurringTransaction,
    TransactionProvider? transactionProvider,
  ) async {
    if (!_initialized) {
      await initialize();
    }
    
    final idx = _recurringTransactions.indexWhere((e) => e.id == recurringTransaction.id);
    if (idx != -1) {
      final oldRecurring = _recurringTransactions[idx];
      _recurringTransactions[idx] = recurringTransaction;
      await RecurringTransactionHiveStorage.updateRecurringTransaction(recurringTransaction);
      
      // Update existing transactions that were created from this recurring transaction
      if (transactionProvider != null) {
        await _updateTransactionsFromRecurring(oldRecurring, recurringTransaction, transactionProvider);
      }
      
      notifyListeners();
    }
  }

  /// Update existing transactions that were created from a recurring transaction
  Future<void> _updateTransactionsFromRecurring(
    RecurringTransaction oldRecurring,
    RecurringTransaction newRecurring,
    TransactionProvider transactionProvider,
  ) async {
    try {
      if (!transactionProvider.isInitialized) {
        await transactionProvider.initialize();
      }

      // Find all transactions created from this recurring transaction
      final allTransactions = transactionProvider.getAllTransactions();
      final transactionsToUpdate = allTransactions
          .where((t) => t.recurringTransactionId == oldRecurring.id)
          .toList();

      // Update each transaction with new recurring transaction details
      for (final transaction in transactionsToUpdate) {
        // Only update if the transaction date matches an occurrence date
        // This prevents updating transactions that were manually edited
        final updatedTransaction = transaction.copyWith(
          title: newRecurring.title,
          amount: newRecurring.amount,
          type: newRecurring.type == 'income' ? TransactionType.income : TransactionType.expense,
          category: newRecurring.category,
          accountId: newRecurring.accountId,
          note: newRecurring.note ?? transaction.note,
        );

        await transactionProvider.update(updatedTransaction);
      }

      if (transactionsToUpdate.isNotEmpty) {
        debugPrint('Updated ${transactionsToUpdate.length} transaction(s) from recurring transaction ${oldRecurring.id}');
      }
    } catch (e) {
      debugPrint('Error updating transactions from recurring transaction: $e');
    }
  }

  Future<void> removeRecurringTransaction(String id) async {
    _recurringTransactions.removeWhere((e) => e.id == id);
    await RecurringTransactionHiveStorage.deleteRecurringTransaction(id);
    notifyListeners();
  }

  RecurringTransaction? getRecurringTransaction(String id) {
    try {
      return _recurringTransactions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  List<RecurringTransaction> getActiveRecurringTransactions() {
    return _recurringTransactions
        .where((recurring) => recurring.isActive && !recurring.hasEnded)
        .toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
  }

  List<RecurringTransaction> getInactiveRecurringTransactions() {
    return _recurringTransactions
        .where((recurring) => !recurring.isActive || recurring.hasEnded)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<RecurringTransaction> getDueRecurringTransactions() {
    return _recurringTransactions
        .where((recurring) => 
            recurring.isActive && 
            !recurring.hasEnded &&
            recurring.isDue)
        .toList()
      ..sort((a, b) => a.nextOccurrence.compareTo(b.nextOccurrence));
  }

  /// Process recurring transactions that are due
  /// Creates actual transactions for due recurring transactions
  Future<void> processRecurringTransactions(TransactionProvider transactionProvider) async {
    if (!_initialized) {
      await initialize();
    }

    final dueRecurring = getDueRecurringTransactions();
    final now = DateTime.now();

    for (final recurring in dueRecurring) {
      // Check if already processed today
      if (recurring.lastProcessedDate != null) {
        final lastProcessed = DateTime(
          recurring.lastProcessedDate!.year,
          recurring.lastProcessedDate!.month,
          recurring.lastProcessedDate!.day,
        );
        final today = DateTime(now.year, now.month, now.day);
        if (lastProcessed.isAtSameMomentAs(today)) {
          continue; // Already processed today
        }
      }

      // Create transaction if auto-approve is enabled
      if (recurring.autoApprove) {
        await _createTransactionFromRecurring(recurring, transactionProvider);
        
        // Update recurring transaction
        final nextOccurrence = recurring.calculateNextOccurrence(recurring.nextOccurrence);
        final updated = recurring.copyWith(
          lastProcessedDate: now,
          nextOccurrence: nextOccurrence,
          totalOccurrences: recurring.totalOccurrences + 1,
        );
        await updateRecurringTransaction(updated, transactionProvider);
      }
      // If not auto-approve, don't update nextOccurrence - keep it in pending state
      // until user explicitly approves or skips it
    }

    notifyListeners();
  }

  /// Create a transaction from a recurring transaction
  Future<void> _createTransactionFromRecurring(
    RecurringTransaction recurring,
    TransactionProvider transactionProvider,
  ) async {
    // Check if a transaction already exists for this recurring transaction and date
    final allTransactions = transactionProvider.getAllTransactions();
    TransactionItem? existingTransaction;
    try {
      existingTransaction = allTransactions.firstWhere(
        (t) => t.recurringTransactionId == recurring.id &&
            t.date.year == recurring.nextOccurrence.year &&
            t.date.month == recurring.nextOccurrence.month &&
            t.date.day == recurring.nextOccurrence.day,
      );
    } catch (e) {
      // No existing transaction found, will create a new one
      existingTransaction = null;
    }

    if (existingTransaction != null) {
      // Update existing transaction instead of creating a new one
      final updatedTransaction = existingTransaction.copyWith(
        title: recurring.title,
        amount: recurring.amount,
        type: recurring.type == 'income' ? TransactionType.income : TransactionType.expense,
        category: recurring.category,
        accountId: recurring.accountId,
        note: recurring.note ?? existingTransaction.note,
      );
      await transactionProvider.update(updatedTransaction);
      debugPrint('Updated existing transaction for recurring ${recurring.id} on ${recurring.nextOccurrence}');
      return;
    }

    // Create new transaction if none exists
    final transaction = TransactionItem(
      id: '${recurring.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: recurring.title,
      amount: recurring.amount,
      type: recurring.type == 'income' ? TransactionType.income : TransactionType.expense,
      date: recurring.nextOccurrence,
      category: recurring.category,
      note: recurring.note ?? 'Recurring: ${recurring.title}',
      accountId: recurring.accountId,
      recurringTransactionId: recurring.id, // Link transaction to recurring transaction
    );

    await transactionProvider.add(transaction);
  }

  /// Approve a pending recurring transaction (create the transaction)
  Future<void> approvePendingTransaction(
    String recurringId,
    TransactionProvider transactionProvider,
  ) async {
    final recurring = getRecurringTransaction(recurringId);
    if (recurring == null || !recurring.isDue) {
      return;
    }

    await _createTransactionFromRecurring(recurring, transactionProvider);

    // Update recurring transaction
    final now = DateTime.now();
    final nextOccurrence = recurring.calculateNextOccurrence(recurring.nextOccurrence);
    final updated = recurring.copyWith(
      lastProcessedDate: now,
      nextOccurrence: nextOccurrence,
      totalOccurrences: recurring.totalOccurrences + 1,
    );
    await updateRecurringTransaction(updated, transactionProvider);

    notifyListeners();
  }

  /// Skip an occurrence without creating a transaction
  Future<void> skipOccurrence(String recurringId) async {
    final recurring = getRecurringTransaction(recurringId);
    if (recurring == null) {
      return;
    }

    final nextOccurrence = recurring.calculateNextOccurrence(recurring.nextOccurrence);
    final updated = recurring.copyWith(
      nextOccurrence: nextOccurrence,
    );
    await updateRecurringTransaction(updated, null); // No transaction updates needed for skipping

    notifyListeners();
  }

  /// Pause a recurring transaction
  Future<void> pauseRecurringTransaction(String id) async {
    final recurring = getRecurringTransaction(id);
    if (recurring != null) {
      final updated = recurring.copyWith(isActive: false);
      await updateRecurringTransaction(updated, null); // No transaction updates needed for pausing
      notifyListeners();
    }
  }

  /// Resume a recurring transaction
  Future<void> resumeRecurringTransaction(String id) async {
    final recurring = getRecurringTransaction(id);
    if (recurring != null) {
      final updated = recurring.copyWith(isActive: true);
      await updateRecurringTransaction(updated, null); // No transaction updates needed for resuming
      notifyListeners();
    }
  }

  /// Sync recurring transactions to Firestore
  Future<bool> syncRecurringTransactionsToFirestore() async {
    try {
      final unsyncedRecurring = RecurringTransactionHiveStorage.getUnsyncedRecurringTransactions();
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // 1. Sync unsynced recurring transactions (new/updated)
      if (unsyncedRecurring.isNotEmpty) {
      for (final recurring in unsyncedRecurring) {
        await firestore
            .collection('recurringTransactions')
            .doc(userId)
            .collection('userRecurringTransactions')
            .doc(recurring.id)
            .set(recurring.toFirestoreMap());

        await RecurringTransactionHiveStorage.markAsSynced(recurring.id);
      }
      }

      // 2. Sync deletions - delete recurring transactions from Firestore that don't exist locally
      await _syncRecurringTransactionDeletions();

      await _loadFromHive();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error syncing recurring transactions: $e');
      return false;
    }
  }

  /// Sync deletions: Delete recurring transactions from Firestore that don't exist locally
  Future<void> _syncRecurringTransactionDeletions() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Get all local recurring transaction IDs
      final localRecurring = RecurringTransactionHiveStorage.getAllRecurringTransactions();
      final localRecurringIds = localRecurring.map((r) => r.id).toSet();

      // Get all recurring transaction IDs from Firestore
      final firestoreSnapshot = await firestore
          .collection('recurringTransactions')
          .doc(userId)
          .collection('userRecurringTransactions')
          .get();

      // Find recurring transactions in Firestore that don't exist locally
      final recurringToDelete = <String>[];
      for (final doc in firestoreSnapshot.docs) {
        if (!localRecurringIds.contains(doc.id)) {
          recurringToDelete.add(doc.id);
        }
      }

      // Delete orphaned recurring transactions from Firestore
      for (final recurringId in recurringToDelete) {
        await firestore
            .collection('recurringTransactions')
            .doc(userId)
            .collection('userRecurringTransactions')
            .doc(recurringId)
            .delete();
        debugPrint('Deleted recurring transaction $recurringId from Firestore');
      }

      if (recurringToDelete.isNotEmpty) {
        debugPrint('Synced ${recurringToDelete.length} recurring transaction deletion(s) to Firestore');
      }
    } catch (e) {
      debugPrint('Error syncing recurring transaction deletions: $e');
    }
  }

  /// Refresh from Hive
  Future<void> refreshFromHive() async {
    await _loadFromHive();
    notifyListeners();
  }

  /// Get sync statistics
  Map<String, int> getSyncStatistics() {
    return RecurringTransactionHiveStorage.getSyncStatistics();
  }

  /// Load recurring transactions from Firestore
  Future<void> loadRecurringTransactionsFromFirestore() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Fetch recurring transactions from Firestore
      final recurringSnapshot = await firestore
          .collection('recurringTransactions')
          .doc(userId)
          .collection('userRecurringTransactions')
          .get();

      if (recurringSnapshot.docs.isNotEmpty) {
        for (final doc in recurringSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to RecurringTransaction
          final recurring = RecurringTransaction.fromFirestoreMap(data, doc.id);

          // Save to Hive (will overwrite local if exists)
          await RecurringTransactionHiveStorage.saveRecurringTransaction(recurring);
        }
        debugPrint("Recurring transactions synced from Firestore to Hive.");
      } else {
        debugPrint("No recurring transactions found in Firestore for this user.");
      }

      // Refresh local data
      await _loadFromHive();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading recurring transactions from Firestore: $e');
    }
  }

  /// Reset and reinitialize the provider (for logout/login)
  Future<void> resetAndInitialize() async {
    _recurringTransactions.clear();
    _initialized = false;
    await initialize();
  }
}

