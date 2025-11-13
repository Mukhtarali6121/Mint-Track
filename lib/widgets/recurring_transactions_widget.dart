import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/recurring_transaction.dart';
import 'package:expense_tracker/presentation/screens/recurring_transactions_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/recurring_transaction_provider.dart';
import '../providers/transaction_provider.dart';

class RecurringTransactionsWidget extends StatefulWidget {
  const RecurringTransactionsWidget({super.key});

  @override
  State<RecurringTransactionsWidget> createState() =>
      _RecurringTransactionsWidgetState();
}

class _RecurringTransactionsWidgetState
    extends State<RecurringTransactionsWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Process recurring transactions when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recurringProvider = context.read<RecurringTransactionProvider>();
      final transactionProvider = context.read<TransactionProvider>();

      if (recurringProvider.isInitialized) {
        recurringProvider.processRecurringTransactions(transactionProvider);
      }
    });
  }

  String _getFrequencyLabel(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.yearly:
        return 'Yearly';
    }
  }

  Future<void> _approvePendingTransaction(
    RecurringTransaction recurring,
    RecurringTransactionProvider recurringProvider,
    TransactionProvider transactionProvider,
  ) async {
    await recurringProvider.approvePendingTransaction(
      recurring.id,
      transactionProvider,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction created successfully'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    }
  }

  Future<void> _skipOccurrence(
    RecurringTransaction recurring,
    RecurringTransactionProvider recurringProvider,
  ) async {
    await recurringProvider.skipOccurrence(recurring.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Occurrence skipped'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final recurringProvider = context.watch<RecurringTransactionProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    // Get pending recurring transactions (due but not auto-approved)
    final pendingRecurring = recurringProvider
        .getDueRecurringTransactions()
        .where((recurring) => !recurring.autoApprove)
        .toList();

    // Get all active recurring transactions for count
    final allActiveRecurring = recurringProvider.getActiveRecurringTransactions();
    
    // Get active recurring transactions (for display - show first 3)
    final activeRecurring = allActiveRecurring.take(3).toList();
    
    // Check if there are more than what's displayed
    final hasMoreActive = allActiveRecurring.length > 3;

    // Don't show widget if no recurring transactions
    if (pendingRecurring.isEmpty && activeRecurring.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.repeat, color: Colors.blue, size: 16),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Recurring Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (pendingRecurring.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${pendingRecurring.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Show pending approvals first
                      if (pendingRecurring.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.pending_actions,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${pendingRecurring.length} pending approval${pendingRecurring.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...pendingRecurring.take(2).map((recurring) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          recurring.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.format(
                                          amount: recurring.amount,
                                          symbol: currencySymbol,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: recurring.type == 'income'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Approve button (checkmark)
                                      InkWell(
                                        onTap: () => _approvePendingTransaction(
                                          recurring,
                                          recurringProvider,
                                          transactionProvider,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentGreen
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: AppColors.accentGreen,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Skip button (X)
                                      InkWell(
                                        onTap: () => _skipOccurrence(
                                          recurring,
                                          recurringProvider,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.grey,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              if (pendingRecurring.length > 2)
                                Text(
                                  '+ ${pendingRecurring.length - 2} more',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Show active recurring transactions
                      if (activeRecurring.isNotEmpty) ...[
                        ...activeRecurring.map((recurring) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: AppColors.border.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          recurring.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (recurring.autoApprove)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentGreen
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Auto',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.accentGreen,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${CurrencyFormatter.format(amount: recurring.amount, symbol: currencySymbol)} • ${_getFrequencyLabel(recurring.frequency)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM dd',
                                        ).format(recurring.nextOccurrence),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      
                      // View All button with date button style (only show if more than 3)
                      if (hasMoreActive || pendingRecurring.length > 2) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RecurringTransactionsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.accentGreen.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'View All',
                                style: TextStyle(
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
              ),
        ],
      ),
    );
  }
}
