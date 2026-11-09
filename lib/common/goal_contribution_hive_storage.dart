import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart' show HiveError;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_contribution.dart';

class GoalContributionHiveStorage {
  static const String _contributionBoxName = 'goal_contributions';
  static Box<GoalContribution>? _contributionBox;

  /// Initialize contribution box
  static Future<void> init() async {
    // Register adapter (typeId: 10)
    if (!Hive.isAdapterRegistered(10)) {
      try {
        Hive.registerAdapter(GoalContributionAdapter());
        debugPrint('GoalContributionAdapter registered successfully with typeId: 10');
      } catch (e) {
        debugPrint('Error registering GoalContributionAdapter: $e');
        rethrow;
      }
    }

    // Close existing box if open
    if (_contributionBox != null && _contributionBox!.isOpen) {
      await _contributionBox!.close();
      _contributionBox = null;
    }

    // Open the box
    if (_contributionBox == null || !_contributionBox!.isOpen) {
      try {
        _contributionBox = await Hive.openBox<GoalContribution>(_contributionBoxName);
        debugPrint('Goal contribution box opened successfully');
      } catch (e) {
        debugPrint('Error opening goal contribution box: $e');
        // If box is corrupted (unknown typeId error), delete it and create a new one
        if (e is HiveError && 
            (e.message.contains('unknown typeId') || 
             e.message.contains('Cannot read') ||
             e.message.contains('typeId: 38'))) {
          debugPrint('Box appears corrupted (unknown typeId), deleting and recreating...');
          try {
            // Close box if it's partially open
            if (_contributionBox != null && _contributionBox!.isOpen) {
              await _contributionBox!.close();
              _contributionBox = null;
            }
            // Delete the corrupted box
            await Hive.deleteBoxFromDisk(_contributionBoxName);
            debugPrint('Deleted corrupted box');
            // Create a new box
            _contributionBox = await Hive.openBox<GoalContribution>(_contributionBoxName);
            debugPrint('Goal contribution box recreated successfully');
          } catch (deleteError) {
            debugPrint('Error recreating box: $deleteError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    }
  }

  /// Get current user ID
  static String _getUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
  }

  /// Save a contribution to Hive
  static Future<void> saveContribution(GoalContribution contribution) async {
    await init();
    if (_contributionBox == null) {
      throw Exception('Contribution box not initialized');
    }
    
    final contributionWithUserId = contribution.copyWith(userId: _getUserId());
    await _contributionBox!.put(contributionWithUserId.id, contributionWithUserId);
    debugPrint('Contribution saved: ${contributionWithUserId.id}');
  }

  /// Get all contributions for a specific goal
  static List<GoalContribution> getContributionsForGoal(String goalId) {
    if (_contributionBox == null || !_contributionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _contributionBox!.values
        .where((contribution) => 
            contribution.userId == userId && 
            contribution.goalId == goalId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Most recent first
  }

  /// Get all contributions
  static List<GoalContribution> getAllContributions() {
    if (_contributionBox == null || !_contributionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _contributionBox!.values
        .where((contribution) => contribution.userId == userId)
        .toList();
  }

  /// Delete a contribution
  static Future<void> deleteContribution(String id) async {
    await init();
    if (_contributionBox == null) {
      throw Exception('Contribution box not initialized');
    }
    
    await _contributionBox!.delete(id);
    debugPrint('Contribution deleted: $id');
  }

  /// Delete contributions for a transaction (when transaction is deleted)
  static Future<void> deleteContributionsForTransaction(String transactionId) async {
    await init();
    if (_contributionBox == null) {
      throw Exception('Contribution box not initialized');
    }
    
    final userId = _getUserId();
    final contributionsToDelete = _contributionBox!.values
        .where((contribution) => 
            contribution.userId == userId && 
            contribution.transactionId == transactionId)
        .toList();
    
    for (final contribution in contributionsToDelete) {
      await _contributionBox!.delete(contribution.id);
    }
    
    if (contributionsToDelete.isNotEmpty) {
      debugPrint('Deleted ${contributionsToDelete.length} contribution(s) for transaction: $transactionId');
    }
  }

  /// Get unsynced contributions
  static List<GoalContribution> getUnsyncedContributions() {
    if (_contributionBox == null || !_contributionBox!.isOpen) {
      return [];
    }
    
    final userId = _getUserId();
    return _contributionBox!.values
        .where((contribution) => contribution.userId == userId && !contribution.isSynced)
        .toList();
  }

  /// Mark a contribution as synced
  static Future<void> markAsSynced(String id) async {
    if (_contributionBox == null) {
      throw Exception('Contribution box not initialized');
    }
    
    final contribution = _contributionBox!.get(id);
    if (contribution != null) {
      final syncedContribution = contribution.copyWith(isSynced: true);
      await _contributionBox!.put(id, syncedContribution);
      debugPrint('Contribution marked as synced: $id');
    }
  }

  /// Clear all contributions (for logout/data cleanup)
  static Future<void> clearAllContributions() async {
    if (_contributionBox != null && _contributionBox!.isOpen) {
      await _contributionBox!.clear();
      debugPrint('All contributions cleared');
    }
  }
}

