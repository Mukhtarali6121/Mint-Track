import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/category_picker.dart';
import '../../models.dart';
import '../../models/recurring_transaction.dart';
import '../../models/account.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/account_provider.dart';

class AddEditRecurringTransactionScreen extends StatefulWidget {
  const AddEditRecurringTransactionScreen({super.key, this.existing});

  final RecurringTransaction? existing;

  @override
  State<AddEditRecurringTransactionScreen> createState() => _AddEditRecurringTransactionScreenState();
}

class _AddEditRecurringTransactionScreenState extends State<AddEditRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _category = 'Others';
  String _selectedAccountId = 'cash';
  bool _autoApprove = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _noteController.text = e.note ?? '';
      _type = e.type == 'income' ? TransactionType.income : TransactionType.expense;
      _frequency = e.frequency;
      _startDate = e.startDate;
      _endDate = e.endDate;
      _category = e.category;
      _selectedAccountId = e.accountId;
      _autoApprove = e.autoApprove;
    } else {
      // Set next occurrence to start date
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDate: _startDate,
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickCategory() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CategoryPickerBottomSheet(
        transactionType: _type,
        selectedCategory: _category,
        onCategorySelected: (category) {
          setState(() => _category = category);
        },
      ),
    );
  }

  Future<void> _pickAccount() async {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No accounts available. Please create an account first.'),
        ),
      );
      return;
    }

    final selectedAccount = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...accounts.map((account) {
              final isSelected = account.id == _selectedAccountId;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: AppColors.accentGreen,
                    size: 20,
                  ),
                ),
                title: Text(
                  account.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: AppColors.accentGreen)
                    : null,
                onTap: () {
                  Navigator.pop(context, account.id);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );

    if (selectedAccount != null) {
      setState(() {
        _selectedAccountId = selectedAccount;
      });
    }
  }

  List<DateTime> _getNextOccurrences() {
    final occurrences = <DateTime>[];
    var currentDate = _startDate;
    final recurring = RecurringTransaction(
      id: 'temp',
      title: _titleController.text,
      amount: double.tryParse(_amountController.text) ?? 0.0,
      type: _type == TransactionType.income ? 'income' : 'expense',
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      nextOccurrence: _startDate,
      category: _category,
      accountId: _selectedAccountId,
      createdAt: DateTime.now(),
      userId: 'temp',
    );

    for (int i = 0; i < 5; i++) {
      if (_endDate != null && currentDate.isAfter(_endDate!)) {
        break;
      }
      occurrences.add(currentDate);
      currentDate = recurring.calculateNextOccurrence(currentDate);
    }

    return occurrences;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final provider = context.read<RecurringTransactionProvider>();
    final now = DateTime.now();

    final recurring = RecurringTransaction(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      amount: amount,
      type: _type == TransactionType.income ? 'income' : 'expense',
      frequency: _frequency,
      startDate: _startDate,
      endDate: _endDate,
      nextOccurrence: widget.existing?.nextOccurrence ?? _startDate, // Preserve existing nextOccurrence when editing
      category: _category,
      accountId: _selectedAccountId,
      isActive: widget.existing?.isActive ?? true,
      autoApprove: _autoApprove,
      lastProcessedDate: widget.existing?.lastProcessedDate, // Preserve existing lastProcessedDate when editing
      totalOccurrences: widget.existing?.totalOccurrences ?? 0, // Preserve existing totalOccurrences when editing
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      userId: widget.existing?.userId ?? '',
      isSynced: widget.existing?.isSynced ?? false,
    );

    if (widget.existing != null) {
      final transactionProvider = context.read<TransactionProvider>();
      await provider.updateRecurringTransaction(recurring, transactionProvider);
    } else {
      await provider.addRecurringTransaction(recurring);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existing != null
              ? 'Recurring transaction updated'
              : 'Recurring transaction created'),
        ),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₹');
    final accountProvider = context.watch<AccountProvider>();
    Account? selectedAccount;
    try {
      selectedAccount = accountProvider.accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
      );
    } catch (e) {
      if (accountProvider.accounts.isNotEmpty) {
        selectedAccount = accountProvider.accounts.first;
        _selectedAccountId = selectedAccount.id;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Recurring Transaction' : 'New Recurring Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type Selection
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      'Expense',
                      style: TextStyle(
                        color: _type == TransactionType.expense 
                            ? Colors.black87 
                            : Colors.black54,
                        fontWeight: _type == TransactionType.expense 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _type == TransactionType.expense,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _type = TransactionType.expense);
                      }
                    },
                    selectedColor: Colors.red.withOpacity(0.2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      'Income',
                      style: TextStyle(
                        color: _type == TransactionType.income 
                            ? Colors.black87 
                            : Colors.black54,
                        fontWeight: _type == TransactionType.income 
                            ? FontWeight.w600 
                            : FontWeight.normal,
                      ),
                    ),
                    selected: _type == TransactionType.income,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _type = TransactionType.income);
                      }
                    },
                    selectedColor: Colors.green.withOpacity(0.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Netflix Subscription',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Frequency
            DropdownButtonFormField<RecurringFrequency>(
              value: _frequency,
              decoration: const InputDecoration(
                labelText: 'Frequency',
                border: OutlineInputBorder(),
              ),
              items: RecurringFrequency.values.map((frequency) {
                return DropdownMenuItem(
                  value: frequency,
                  child: Text(_getFrequencyLabel(frequency)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _frequency = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Start Date
            InkWell(
              onTap: _pickStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('MMM dd, yyyy').format(_startDate)),
              ),
            ),
            const SizedBox(height: 16),

            // End Date (Optional)
            InkWell(
              onTap: _pickEndDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'End Date (Optional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: _endDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _endDate = null);
                          },
                        )
                      : const Icon(Icons.calendar_today),
                ),
                child: Text(_endDate != null
                    ? DateFormat('MMM dd, yyyy').format(_endDate!)
                    : 'No end date'),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            InkWell(
              onTap: _pickCategory,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(_category),
              ),
            ),
            const SizedBox(height: 16),

            // Account
            InkWell(
              onTap: _pickAccount,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Account',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                child: Text(selectedAccount?.name ?? 'No account'),
              ),
            ),
            const SizedBox(height: 16),

            // Auto Approve
            SwitchListTile(
              title: const Text('Auto Approve'),
              subtitle: const Text('Automatically create transactions without approval'),
              value: _autoApprove,
              onChanged: (value) {
                setState(() => _autoApprove = value);
              },
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add a note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Preview Next Occurrences
            if (_titleController.text.isNotEmpty && _amountController.text.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next 5 Occurrences',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._getNextOccurrences().map((date) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('MMM dd, yyyy').format(date)),
                              Text(
                                currency.format(double.tryParse(_amountController.text) ?? 0.0),
                                style: TextStyle(
                                  color: _type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(widget.existing != null ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

