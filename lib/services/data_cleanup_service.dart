import 'package:hive_flutter/hive_flutter.dart';
import '../common/transaction_hive_storage.dart';
import '../common/hive_storage.dart';
import '../common/account_hive_storage.dart';
import '../common/goal_hive_storage.dart';
import '../common/local_storage.dart';

/// Service to clear all local data
class DataCleanupService {
  /// Clear all local data including:
  /// - All transactions from Hive
  /// - All accounts from Hive
  /// - All goals from Hive
  /// - Setup data from Hive
  /// - User profile from Hive
  /// - SharedPreferences
  static Future<void> clearAllData() async {
    try {
      // Clear all transactions
      await TransactionHiveStorage.clearAllTransactions();
      
      // Clear all accounts
      await AccountHiveStorage.clearAllAccounts();
      
      // Clear all goals
      await GoalHiveStorage.clearAllGoals();
      
      // Clear setup data
      await HiveStorage.deleteSetupData();
      
      // Clear user profile
      await HiveStorage.clearUserProfile();
      
      // Clear SharedPreferences
      await LocalStorage().clear();
      
      print('DataCleanupService: All local data cleared successfully');
    } catch (e) {
      print('DataCleanupService: Error clearing data: $e');
      rethrow;
    }
  }
}

