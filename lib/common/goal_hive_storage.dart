import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart' show HiveError;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal.dart';

class GoalHiveStorage {
  static const String _goalBoxName = 'goals';
  static const String _deletedGoalBoxName = 'deleted_goals';
  static Box<Goal>? _goalBox;
  static Box<String>? _deletedBox;

  /// Initialize goal box
  static Future<void> init() async {
    // Register GoalType enum adapter first (typeId: 5)
    if (!Hive.isAdapterRegistered(5)) {
      try {
        Hive.registerAdapter(GoalTypeAdapter());
        debugPrint('GoalTypeAdapter registered successfully with typeId: 5');
      } catch (e) {
        debugPrint('Error registering GoalTypeAdapter: $e');
        rethrow;
      }
    }
    
    // Always register adapter first to ensure it's available
    if (!Hive.isAdapterRegistered(4)) {
      try {
        Hive.registerAdapter(GoalAdapter());
        debugPrint('GoalAdapter registered successfully with typeId: 4');
      } catch (e) {
        debugPrint('Error registering GoalAdapter: $e');
        rethrow;
      }
    } else {
      debugPrint('GoalAdapter already registered');
    }

    // Close existing box if open (to ensure adapter is used)
    if (_goalBox != null && _goalBox!.isOpen) {
      await _goalBox!.close();
      _goalBox = null;
    }

    // Open the box with the registered adapter
    if (_goalBox == null || !_goalBox!.isOpen) {
      try {
        _goalBox = await Hive.openBox<Goal>(_goalBoxName);
        debugPrint('Goal box opened successfully');
      } catch (e) {
        debugPrint('Error opening goal box: $e');
        debugPrint('Adapter registered: ${Hive.isAdapterRegistered(4)}');
        // If box is corrupted (type mismatch or unknown typeId), delete it and create a new one
        if (e is HiveError && 
            (e.message.contains('type cast') || 
             e.message.contains('subtype') ||
             e.message.contains('unknown typeId') ||
             e.message.contains('Cannot read'))) {
          debugPrint('Goal box appears corrupted, deleting and recreating...');
          try {
            // Close box if it's partially open
            if (_goalBox != null && _goalBox!.isOpen) {
              await _goalBox!.close();
              _goalBox = null;
            }
            // Delete the corrupted box
            await Hive.deleteBoxFromDisk(_goalBoxName);
            debugPrint('Deleted corrupted goal box');
            // Create a new box
            _goalBox = await Hive.openBox<Goal>(_goalBoxName);
            debugPrint('Goal box recreated successfully');
          } catch (deleteError) {
            debugPrint('Error recreating goal box: $deleteError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    }

    if (_deletedBox == null || !_deletedBox!.isOpen) {
      _deletedBox = await Hive.openBox<String>(_deletedGoalBoxName);
    }
  }

  /// Get current user ID
  static String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  /// Save a goal to Hive
  static Future<void> saveGoal(Goal goal) async {
    await init();
    if (_goalBox == null) {
      throw Exception('Goal box not initialized');
    }
    
    // Ensure userId matches current user
    final goalWithUserId = goal.copyWith(userId: _getUserId());
    await _goalBox!.put(goalWithUserId.id, goalWithUserId);
    debugPrint('Goal saved: ${goalWithUserId.id}');
  }

  /// Update a goal in Hive
  static Future<void> updateGoal(Goal goal) async {
    await init();
    if (_goalBox == null) {
      throw Exception('Goal box not initialized');
    }
    
    final goalWithUserId = goal.copyWith(userId: _getUserId());
    await _goalBox!.put(goalWithUserId.id, goalWithUserId);
    debugPrint('Goal updated: ${goalWithUserId.id}');
  }

  /// Track a deleted goal ID for cloud sync
  static Future<void> _trackDeletedGoal(String goalId, String userId) async {
    if (_deletedBox == null || !_deletedBox!.isOpen) {
      _deletedBox = await Hive.openBox<String>(_deletedGoalBoxName);
    }
    await _deletedBox!.put(goalId, userId);
  }

  /// Get pending deleted goal IDs for current user
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

  /// Clear synced deleted goal IDs
  static Future<void> clearDeletedIds(List<String> ids) async {
    if (_deletedBox == null || !_deletedBox!.isOpen) return;
    for (final id in ids) {
      await _deletedBox!.delete(id);
    }
  }

  /// Delete a goal from Hive
  static Future<void> deleteGoal(String id) async {
    await init();
    if (_goalBox == null) {
      throw Exception('Goal box not initialized');
    }
    
    final goal = _goalBox!.get(id);
    final userId = goal?.userId ?? _getUserId();
    await _trackDeletedGoal(id, userId);
    await _goalBox!.delete(id);
    debugPrint('Goal deleted: $id');
  }

  /// Get a goal by ID
  static Goal? getGoal(String id) {
    if (_goalBox == null || !_goalBox!.isOpen) {
      return null;
    }
    return _goalBox!.get(id);
  }

  /// Get all goals for current user
  static List<Goal> getAllGoals() {
    if (_goalBox == null || !_goalBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _goalBox!.values
        .where((goal) => goal.userId == userId)
        .toList();
  }

  /// Get unsynced goals
  static List<Goal> getUnsyncedGoals() {
    if (_goalBox == null || !_goalBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _goalBox!.values
        .where((goal) => goal.userId == userId && !goal.isSynced)
        .toList();
  }

  /// Mark a goal as synced
  static Future<void> markAsSynced(String id) async {
    await init();
    if (_goalBox == null) {
      throw Exception('Goal box not initialized');
    }
    
    final goal = _goalBox!.get(id);
    if (goal != null) {
      final syncedGoal = goal.copyWith(isSynced: true);
      await _goalBox!.put(id, syncedGoal);
      debugPrint('Goal marked as synced: $id');
    }
  }

  /// Mark multiple goals as synced using atomic putAll
  static Future<void> markMultipleAsSynced(List<String> ids) async {
    await init();
    if (_goalBox == null) {
      throw Exception('Goal box not initialized');
    }
    
    final Map<String, Goal> updates = {};
    for (final id in ids) {
      final goal = _goalBox!.get(id);
      if (goal != null) {
        updates[id] = goal.copyWith(isSynced: true);
      }
    }
    if (updates.isNotEmpty) {
      await _goalBox!.putAll(updates);
    }
  }

  /// Get sync statistics
  static Map<String, int> getSyncStatistics() {
    if (_goalBox == null || !_goalBox!.isOpen) {
      return {'total': 0, 'synced': 0, 'unsynced': 0, 'pendingDeletions': 0};
    }
    
    final userId = _getUserId();
    final allGoals = _goalBox!.values
        .where((goal) => goal.userId == userId)
        .toList();
    
    final synced = allGoals.where((goal) => goal.isSynced).length;
    final unsynced = allGoals.length - synced;
    final pendingDeletions = getPendingDeletedIds().length;
    
    return {
      'total': allGoals.length,
      'synced': synced,
      'unsynced': unsynced,
      'pendingDeletions': pendingDeletions,
    };
  }

  /// Clear all goals (for logout/data cleanup)
  static Future<void> clearAllGoals() async {
    if (_goalBox != null && _goalBox!.isOpen) {
      await _goalBox!.clear();
      debugPrint('All goals cleared');
    }
  }
}

