import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/presentation/screens/add_edit_account_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../account_provider.dart';
import '../../transaction_provider.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Future<void> _deleteAccount(BuildContext context, Account account) async {
    // Prevent deletion of Cash account
    if (account.id == 'cash') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cash account cannot be deleted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check if account has transactions
    final transactionProvider = context.read<TransactionProvider>();
    final accountTransactions = transactionProvider.getTransactionsByAccount(account.id);

    if (accountTransactions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Account'),
          content: Text(
            'This account has ${accountTransactions.length} transaction(s). '
            'Please reassign or delete these transactions first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to delete "${account.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<AccountProvider>();
      await provider.removeAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${account.name}" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final String currencySymbol = currencyProvider.currencySymbol;
    final accountProvider = context.watch<AccountProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    final accounts = accountProvider.accounts;

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        title: const Text(
          'Accounts',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Accounts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first account to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final balance = transactionProvider.getAccountBalance(account.id);
                final income = transactionProvider.getAccountIncome(account.id);
                final expense = transactionProvider.getAccountExpense(account.id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.accentGreen,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      account.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Balance: ${CurrencyFormatter.format(amount: balance, symbol: currencySymbol, decimalDigits: 2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: balance >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Income: ${CurrencyFormatter.format(amount: income, symbol: currencySymbol, decimalDigits: 2)} • '
                          'Expense: ${CurrencyFormatter.format(amount: expense, symbol: currencySymbol, decimalDigits: 2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditAccountScreen(existing: account),
                            ),
                          ).then((_) {
                            setState(() {});
                          });
                        } else if (value == 'delete') {
                          _deleteAccount(context, account);
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
                        // Hide delete option for Cash account
                        if (account.id != 'cash')
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditAccountScreen(),
            ),
          ).then((_) {
            setState(() {});
          });
        },
        backgroundColor: AppColors.accentGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

