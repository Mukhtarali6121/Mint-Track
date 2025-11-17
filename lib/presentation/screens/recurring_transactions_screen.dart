import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/recurring_transaction.dart';
import 'package:expense_tracker/presentation/screens/add_edit_recurring_transaction_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/premium_provider.dart';
import '../../common/premium_constants.dart';
import 'premium_upgrade_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Initialize providers if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final recurringProvider = context.read<RecurringTransactionProvider>();
      final transactionProvider = context.read<TransactionProvider>();
      
      if (!recurringProvider.isInitialized) {
        recurringProvider.initialize();
      }
      
      // Process recurring transactions on screen load
      recurringProvider.processRecurringTransactions(transactionProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    await recurringProvider.approvePendingTransaction(recurring.id, transactionProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction created successfully')),
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
        const SnackBar(content: Text('Occurrence skipped')),
      );
    }
  }

  Future<void> _deleteRecurringTransaction(
    RecurringTransaction recurring,
    RecurringTransactionProvider recurringProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Transaction'),
        content: Text('Are you sure you want to delete "${recurring.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await recurringProvider.removeRecurringTransaction(recurring.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring transaction deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = context.watch<CurrencyProvider>();
    final currencySymbol = currencyProvider.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Active', icon: Icon(Icons.repeat)),
            Tab(text: 'Inactive', icon: Icon(Icons.pause_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(currencySymbol),
          _buildActiveTab(currencySymbol),
          _buildInactiveTab(currencySymbol),
        ],
      ),
      floatingActionButton: Consumer<PremiumProvider>(
        builder: (context, premiumProvider, _) {
          final recurringProvider = context.watch<RecurringTransactionProvider>();
          final canAdd = recurringProvider.canAddRecurringTransaction();
          final recurringCount = recurringProvider.getRecurringTransactionCount();
          final isPremium = premiumProvider.isPremium;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Show recurring transaction limit indicator for free users
              if (!isPremium)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: canAdd ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: canAdd ? Colors.blue.shade200 : Colors.orange.shade300,
                    ),
                  ),
                  child: Text(
                    '$recurringCount/${PremiumConstants.FREE_MAX_RECURRING_TRANSACTIONS} recurring',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: canAdd ? Colors.blue.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              FloatingActionButton(
                onPressed: canAdd
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddEditRecurringTransactionScreen(),
                          ),
                        );
                      }
                    : () {
                        // Show upgrade prompt
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Recurring Transaction Limit Reached'),
                            content: Text(
                              'You have reached the limit of ${PremiumConstants.FREE_MAX_RECURRING_TRANSACTIONS} recurring transactions. Upgrade to Premium for unlimited recurring transactions.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PremiumUpgradeScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentGreen,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Upgrade'),
                              ),
                            ],
                          ),
                        );
                      },
                backgroundColor: canAdd ? AppColors.accentGreen : Colors.grey,
                child: const Icon(Icons.add),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(String currencySymbol) {
    return Consumer<RecurringTransactionProvider>(
      builder: (context, recurringProvider, _) {
        final transactionProvider = context.read<TransactionProvider>();
        final dueRecurring = recurringProvider.getDueRecurringTransactions()
            .where((recurring) => !recurring.autoApprove)
            .toList();

        if (dueRecurring.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending approvals',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: dueRecurring.length,
          itemBuilder: (context, index) {
            final recurring = dueRecurring[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            recurring.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.format(amount: recurring.amount, symbol: currencySymbol),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: recurring.type == 'income' ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _getFrequencyLabel(recurring.frequency),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Next: ${DateFormat('MMM dd, yyyy').format(recurring.nextOccurrence)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _skipOccurrence(recurring, recurringProvider),
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approvePendingTransaction(
                              recurring,
                              recurringProvider,
                              transactionProvider,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGreen,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveTab(String currencySymbol) {
    return Consumer<RecurringTransactionProvider>(
      builder: (context, recurringProvider, _) {
        final activeRecurring = recurringProvider.getActiveRecurringTransactions();

        if (activeRecurring.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.repeat,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active recurring transactions',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap + to create one',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeRecurring.length,
          itemBuilder: (context, index) {
            final recurring = activeRecurring[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  recurring.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.format(amount: recurring.amount, symbol: currencySymbol)} • ${_getFrequencyLabel(recurring.frequency)}',
                    ),
                    Text(
                      'Next: ${DateFormat('MMM dd, yyyy').format(recurring.nextOccurrence)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (recurring.autoApprove)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Auto-approve',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.accentGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddEditRecurringTransactionScreen(existing: recurring),
                        ),
                      );
                    } else if (value == 'pause') {
                      await recurringProvider.pauseRecurringTransaction(recurring.id);
                    } else if (value == 'delete') {
                      await _deleteRecurringTransaction(recurring, recurringProvider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pause',
                      child: Row(
                        children: [
                          Icon(Icons.pause, size: 20),
                          SizedBox(width: 8),
                          Text('Pause'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditRecurringTransactionScreen(existing: recurring),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInactiveTab(String currencySymbol) {
    return Consumer<RecurringTransactionProvider>(
      builder: (context, recurringProvider, _) {
        final inactiveRecurring = recurringProvider.getInactiveRecurringTransactions();

        if (inactiveRecurring.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pause_circle_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No inactive recurring transactions',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: inactiveRecurring.length,
          itemBuilder: (context, index) {
            final recurring = inactiveRecurring[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  recurring.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.format(amount: recurring.amount, symbol: currencySymbol)} • ${_getFrequencyLabel(recurring.frequency)}',
                    ),
                    Text(
                      'Processed ${recurring.totalOccurrences} times',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'resume') {
                      await recurringProvider.resumeRecurringTransaction(recurring.id);
                    } else if (value == 'delete') {
                      await _deleteRecurringTransaction(recurring, recurringProvider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'resume',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow, size: 20),
                          SizedBox(width: 8),
                          Text('Resume'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

