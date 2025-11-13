import 'package:flutter/foundation.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/transaction_provider.dart';
import 'notification_service.dart';

class RecurringTransactionService {
  static final RecurringTransactionService _instance = RecurringTransactionService._internal();
  factory RecurringTransactionService() => _instance;
  RecurringTransactionService._internal();

  /// Check for due recurring transactions and process them
  /// This should be called on app startup and periodically
  Future<void> checkAndProcessRecurringTransactions(
    RecurringTransactionProvider recurringProvider,
    TransactionProvider transactionProvider,
  ) async {
    try {
      // Process recurring transactions
      await recurringProvider.processRecurringTransactions(transactionProvider);

      // Check for pending approvals (due but not auto-approved)
      final dueRecurring = recurringProvider.getDueRecurringTransactions()
          .where((recurring) => !recurring.autoApprove)
          .toList();

      if (dueRecurring.isNotEmpty) {
        // Send notification for pending approvals
        await _sendPendingApprovalNotification(dueRecurring.length);
      }
    } catch (e) {
      debugPrint('Error checking recurring transactions: $e');
    }
  }

  /// Send notification for pending recurring transaction approvals
  Future<void> _sendPendingApprovalNotification(int count) async {
    try {
      final notificationService = NotificationService();
      
      if (count == 1) {
        await notificationService.showNotification(
          id: 100, // Use ID 100+ for recurring transaction notifications
          title: '💰 Recurring Transaction Pending',
          body: 'You have 1 recurring transaction waiting for approval',
          payload: 'recurring_pending',
        );
      } else {
        await notificationService.showNotification(
          id: 100,
          title: '💰 Recurring Transactions Pending',
          body: 'You have $count recurring transactions waiting for approval',
          payload: 'recurring_pending',
        );
      }
    } catch (e) {
      debugPrint('Error sending recurring transaction notification: $e');
    }
  }

  /// Schedule daily check for recurring transactions
  /// This should be called once during app initialization
  Future<void> scheduleDailyCheck() async {
    // The actual scheduling will be handled by the app lifecycle
    // This method can be used to set up any background tasks if needed
    debugPrint('Recurring transaction daily check scheduled');
  }
}

