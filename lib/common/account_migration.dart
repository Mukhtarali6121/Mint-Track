import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/account.dart';
import '../models/hive_transaction.dart';
import '../common/account_hive_storage.dart';
import '../common/transaction_hive_storage.dart';

class AccountMigration {
  /// Run migration to assign existing transactions to Cash account
  /// and create default Cash account if it doesn't exist
  static Future<void> migrateToAccounts() async {
    try {
      await AccountHiveStorage.init();
      await TransactionHiveStorage.init();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final cashAccountId = 'cash';

      // Step 1: Create default Cash account if it doesn't exist
      await AccountHiveStorage.initializeDefaultCashAccount();

      // Step 2: Get all existing transactions
      final allTransactions = TransactionHiveStorage.getAllTransactions();

      // Step 3: Update transactions that don't have accountId
      bool hasUpdates = false;
      for (final transaction in allTransactions) {
        // Check if transaction is missing accountId or has empty/null accountId
        if (transaction.accountId.isEmpty || transaction.accountId == 'cash') {
          // Only update if accountId is actually missing (empty string)
          // We'll use a placeholder to check - if accountId field doesn't exist in old data
          // For now, we'll update all transactions to ensure they have accountId
          if (transaction.accountId.isEmpty || transaction.accountId != cashAccountId) {
            final updatedTransaction = transaction.copyWith(accountId: cashAccountId);
            await TransactionHiveStorage.updateTransaction(updatedTransaction);
            hasUpdates = true;
          }
        }
      }

      if (hasUpdates) {
        debugPrint('Account migration completed: ${allTransactions.length} transactions assigned to Cash account');
      } else {
        debugPrint('Account migration: No transactions needed updating');
      }

      // Step 4: Ensure Cash account is synced (will be synced later when sync runs)
      final cashAccount = AccountHiveStorage.getAccount(cashAccountId);
      if (cashAccount != null && !cashAccount.isSynced) {
        // Mark for sync - will be synced when user syncs accounts
        debugPrint('Cash account created and ready for sync');
      }
    } catch (e) {
      debugPrint('Error during account migration: $e');
    }
  }

  /// Check if migration is needed
  /// Returns true if there are transactions without accountId
  static bool needsMigration() {
    try {
      final allTransactions = TransactionHiveStorage.getAllTransactions();
      // Check if any transaction has empty accountId
      // Note: This is a simplified check - in reality, old transactions might not have the field at all
      // But since we're using Hive with default values, new transactions will have 'cash'
      return allTransactions.any((t) => t.accountId.isEmpty);
    } catch (e) {
      debugPrint('Error checking migration status: $e');
      return false;
    }
  }
}

