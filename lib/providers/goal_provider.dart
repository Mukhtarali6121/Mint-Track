import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal.dart';
import '../common/goal_hive_storage.dart';
import 'transaction_provider.dart';
import '../models.dart';

class GoalProvider extends ChangeNotifier {
  GoalProvider();

  final List<Goal> _goals = <Goal>[];
  bool _initialized = false;

  List<Goal> get goals => List.unmodifiable(_goals);
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await GoalHiveStorage.init();
    await _loadFromHive();
    
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromHive() async {
    final hiveGoals = GoalHiveStorage.getAllGoals();
    _goals.clear();
    _goals.addAll(hiveGoals);
  }

  String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  Future<void> addGoal(Goal goal) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }
    
    // Add to local list
    _goals.add(goal);
    
    // Save to Hive
    await GoalHiveStorage.saveGoal(goal);
    
    notifyListeners();
  }

  Future<void> updateGoal(Goal goal) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }
    
    final idx = _goals.indexWhere((e) => e.id == goal.id);
    if (idx != -1) {
      _goals[idx] = goal;
      
      // Update in Hive
      await GoalHiveStorage.updateGoal(goal);
      
      notifyListeners();
    }
  }

  Future<void> removeGoal(String id) async {
    _goals.removeWhere((e) => e.id == id);
    await GoalHiveStorage.deleteGoal(id);
    notifyListeners();
  }

  Goal? getGoal(String id) {
    try {
      return _goals.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Goal> getAllGoals() {
    return List<Goal>.from(_goals);
  }

  List<Goal> getActiveGoals() {
    return _goals.where((goal) => !goal.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  List<Goal> getCompletedGoals() {
    return _goals.where((goal) => goal.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  List<Goal> getSavingGoals() {
    return _goals.where((goal) => goal.type == GoalType.saving).toList();
  }

  List<Goal> getSpendingLimitGoals() {
    return _goals.where((goal) => goal.type == GoalType.spendingLimit).toList();
  }

  /// Calculate progress for a goal based on transactions
  double calculateProgress(Goal goal, TransactionProvider transactionProvider) {
    if (goal.targetAmount == null) {
      return 0.0; // Text-only goals have no progress
    }

    final allTransactions = transactionProvider.items;
    double totalAmount = 0.0;

    if (goal.type == GoalType.saving) {
      // For saving goals, sum income transactions
      var relevantTransactions = allTransactions
          .where((t) => t.type == TransactionType.income);

      // Filter by account if specified
      if (goal.accountId != null) {
        relevantTransactions = relevantTransactions
            .where((t) => t.accountId == goal.accountId);
      }

      // Filter by category if specified
      if (goal.categoryId != null) {
        relevantTransactions = relevantTransactions
            .where((t) => t.category == goal.categoryId);
      }

      // Sum amounts
      totalAmount = relevantTransactions.fold(0.0, (total, t) => total + t.amount);
    } else if (goal.type == GoalType.spendingLimit) {
      // For spending limits, sum expense transactions
      var relevantTransactions = allTransactions
          .where((t) => t.type == TransactionType.expense);

      // Filter by account if specified
      if (goal.accountId != null) {
        relevantTransactions = relevantTransactions
            .where((t) => t.accountId == goal.accountId);
      }

      // Filter by category if specified
      if (goal.categoryId != null) {
        relevantTransactions = relevantTransactions
            .where((t) => t.category == goal.categoryId);
      }

      // Sum amounts
      totalAmount = relevantTransactions.fold(0.0, (total, t) => total + t.amount);
    }

    // Update goal's current amount and check completion
    final wasCompleted = goal.isCompleted;
    
    // Only auto-complete goals with target amounts when they reach the target
    // Goals without target amounts can only be manually completed
    final isNowCompleted = goal.targetAmount != null 
        ? (totalAmount >= goal.targetAmount!)
        : goal.isCompleted; // Preserve manual completion status for goals without target amounts
    
    final updatedGoal = goal.copyWith(
      currentAmount: totalAmount,
      isCompleted: isNowCompleted,
    );

    // Update in list if changed
    final idx = _goals.indexWhere((e) => e.id == goal.id);
    if (idx != -1) {
      _goals[idx] = updatedGoal;
      
      // Save to Hive immediately when goal becomes completed (important for persistence)
      if (!wasCompleted && isNowCompleted) {
        GoalHiveStorage.updateGoal(updatedGoal);
      }
      // Otherwise, don't save to Hive here to avoid excessive writes - will be saved on sync
    }

    return totalAmount;
  }

  /// Update progress for all goals
  Future<void> updateAllProgress(TransactionProvider transactionProvider) async {
    for (final goal in _goals) {
      calculateProgress(goal, transactionProvider);
    }
    notifyListeners();
  }

  // Sync related methods
  List<Goal> getUnsyncedGoals() {
    return GoalHiveStorage.getUnsyncedGoals();
  }

  Map<String, int> getSyncStatistics() {
    return GoalHiveStorage.getSyncStatistics();
  }

  Future<bool> syncGoalsToFirestore() async {
    try {
      final unsyncedGoals = getUnsyncedGoals();
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // 1. Sync unsynced goals (new/updated)
      if (unsyncedGoals.isNotEmpty) {
      for (final goal in unsyncedGoals) {
        await firestore
            .collection('goals')
            .doc(userId) // document for the user
            .collection('userGoals') // subcollection for this user's goals
            .doc(goal.id)
            .set(goal.toFirestoreMap());

        // Mark as synced in Hive
        await GoalHiveStorage.markAsSynced(goal.id);
      }
      }

      // 2. Sync deletions - delete goals from Firestore that don't exist locally
      await _syncGoalDeletions();

      // Refresh local data
      await _loadFromHive();
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error syncing goals: $e');
      return false;
    }
  }

  /// Sync deletions: Delete goals from Firestore that don't exist locally
  Future<void> _syncGoalDeletions() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Get all local goal IDs
      final localGoals = GoalHiveStorage.getAllGoals();
      final localGoalIds = localGoals.map((g) => g.id).toSet();

      // Get all goal IDs from Firestore
      final firestoreSnapshot = await firestore
          .collection('goals')
          .doc(userId)
          .collection('userGoals')
          .get();

      // Find goals in Firestore that don't exist locally
      final goalsToDelete = <String>[];
      for (final doc in firestoreSnapshot.docs) {
        if (!localGoalIds.contains(doc.id)) {
          goalsToDelete.add(doc.id);
        }
      }

      // Delete orphaned goals from Firestore
      for (final goalId in goalsToDelete) {
        await firestore
            .collection('goals')
            .doc(userId)
            .collection('userGoals')
            .doc(goalId)
            .delete();
        debugPrint('Deleted goal $goalId from Firestore');
      }

      if (goalsToDelete.isNotEmpty) {
        debugPrint('Synced ${goalsToDelete.length} goal deletion(s) to Firestore');
      }
    } catch (e) {
      debugPrint('Error syncing goal deletions: $e');
    }
  }

  Future<void> loadGoalsFromFirestore() async {
    try {
      final userId = _getUserId();
      final firestore = FirebaseFirestore.instance;

      // Fetch goals from Firestore
      final goalsSnapshot = await firestore
          .collection('goals')
          .doc(userId)
          .collection('userGoals')
          .get();

      if (goalsSnapshot.docs.isNotEmpty) {
        for (final doc in goalsSnapshot.docs) {
          final data = doc.data();
          // Convert Firestore data to Goal
          final goal = Goal.fromFirestoreMap(data, doc.id);

          // Save to Hive (will overwrite local if exists)
          await GoalHiveStorage.saveGoal(goal);
        }
        debugPrint("Goals synced from Firestore to Hive.");
      } else {
        debugPrint("No goals found in Firestore for this user.");
      }

      // Refresh local data
      await _loadFromHive();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading goals from Firestore: $e');
    }
  }

  Future<void> refreshFromHive() async {
    await _loadFromHive();
    notifyListeners();
  }

  /// Reset and reinitialize the provider (for logout/login)
  Future<void> resetAndInitialize() async {
    _goals.clear();
    _initialized = false;
    await initialize();
  }
}

