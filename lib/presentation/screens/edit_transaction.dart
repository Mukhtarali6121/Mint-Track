import 'package:expense_tracker/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/category_picker.dart';
import '../../widgets/goal_selection_dialog.dart';
import '../../models.dart';
import '../../models/dynamic_category.dart';
import '../../models/recurring_transaction.dart';
import '../../models/goal_contribution.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../providers/goal_provider.dart';
import '../../common/feature_flags.dart';
import '../../common/goal_contribution_hive_storage.dart';

class EditTransactionScreen extends StatefulWidget {
  const EditTransactionScreen({super.key, this.existing});
  final TransactionItem? existing;

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  TransactionType _type = TransactionType.expense;
  String _category = 'Others';
  String _selectedAccountId = 'cash';
  bool _makeRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;
  bool _isSaving = false;
  bool _addToGoal = false;
  String? _selectedGoalId;

  String _getCategoryIconPath(String categoryName) {
    final dynamicCategory =
    DynamicCategory(name: categoryName, iconName: categoryName);
    return dynamicCategory.iconPath;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _noteController.text = e.note ?? '';
      _date = e.date;
      _type = e.type;
      _category = e.category;
      _selectedAccountId = e.accountId;
    }
    // Default account will be set in build method if needed
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
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

  Future<void> _save() async {
    // Prevent multiple simultaneous saves
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
    // Validate amount
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount'),
          backgroundColor: Colors.orange,
        ),
      );
        }
        setState(() {
          _isSaving = false;
        });
      return;
    }
    
    final parsedAmount = double.tryParse(amountText);
    if (parsedAmount == null || parsedAmount <= 0) {
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
        }
        setState(() {
          _isSaving = false;
        });
      return;
    }
    
    // Validate title if recurring is enabled
    if (_makeRecurring && FeatureFlags.recurringTransactionsFeatureEnabled && _titleController.text.trim().isEmpty) {
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required for recurring transactions'),
          backgroundColor: Colors.orange,
        ),
      );
        }
        setState(() {
          _isSaving = false;
        });
      return;
    }
    
      final provider = context.read<TransactionProvider>();
      
      // If make recurring is enabled, create recurring transaction first to get its ID
      String? recurringTransactionId;
      if (widget.existing == null && _makeRecurring && FeatureFlags.recurringTransactionsFeatureEnabled) {
        final recurringProvider = context.read<RecurringTransactionProvider>();
        
        // Create a temporary recurring transaction to calculate next occurrence
        final tempRecurring = RecurringTransaction(
          id: '',
          title: '',
          amount: 0,
          type: 'expense',
          frequency: _recurringFrequency,
          startDate: _date,
          endDate: null,
          nextOccurrence: _date,
          category: '',
          accountId: '',
          isActive: true,
          autoApprove: true,
          lastProcessedDate: null,
          totalOccurrences: 0,
          note: null,
          createdAt: DateTime.now(),
          userId: '',
          isSynced: false,
        );
        
        // Calculate the next occurrence date (not today, since we already created today's transaction)
        final nextOccurrenceDate = tempRecurring.calculateNextOccurrence(_date);
        final now = DateTime.now();
        
        final recurringTransaction = RecurringTransaction(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          amount: parsedAmount,
          type: _type == TransactionType.expense ? 'expense' : 'income',
          frequency: _recurringFrequency,
          startDate: _date,
          endDate: null,
          nextOccurrence: nextOccurrenceDate, // Set to next occurrence, not today
          category: _category,
          accountId: _selectedAccountId,
          isActive: true,
          autoApprove: true, // Auto-approve recurring transactions created from edit transaction
          lastProcessedDate: now, // Mark today as processed since we already created the transaction
          totalOccurrences: 1, // We've already created the first occurrence
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          createdAt: DateTime.now(),
          userId: '',
          isSynced: false,
        );
        await recurringProvider.addRecurringTransaction(recurringTransaction);
        recurringTransactionId = recurringTransaction.id;
      }
      
      final newItem = TransactionItem(
        id: widget.existing?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        amount: parsedAmount,
        type: _type,
        date: _date,
        category: _category,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        accountId: _selectedAccountId,
        recurringTransactionId: recurringTransactionId, // Link to recurring transaction if created
      );
      String? transactionId;
      if (widget.existing == null) {
        await provider.add(newItem);
        transactionId = newItem.id;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction and recurring transaction created!'),
              backgroundColor: AppColors.accentGreen,
            ),
          );
        }
      } else {
        await provider.update(newItem);
        transactionId = newItem.id;
      }

      // Add contribution to goal if checkbox was checked
      if (_addToGoal && _selectedGoalId != null && FeatureFlags.goalsFeatureEnabled) {
        await GoalContributionHiveStorage.init();
        final contribution = GoalContribution(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          goalId: _selectedGoalId!,
          amount: parsedAmount,
          transactionId: transactionId,
          date: _date,
          createdAt: DateTime.now(),
          userId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
          isSynced: false,
        );
        await GoalContributionHiveStorage.saveContribution(contribution);
        
        // Update goal progress
        final goalProvider = context.read<GoalProvider>();
        final goal = goalProvider.getGoal(_selectedGoalId!);
        if (goal != null) {
          await goalProvider.updateAllProgress(context.read<TransactionProvider>());
        }
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // 🔸 Add to Goal Checkbox
  Widget _buildAddToGoalCheckbox() {
    return InkWell(
      onTap: () async {
        if (!_addToGoal) {
          // Show goal selection dialog
          final amount = double.tryParse(_amountController.text) ?? 0.0;
          if (amount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter an amount first'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          final transactionId = widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
          final selectedGoalId = await showDialog<String>(
            context: context,
            builder: (context) => GoalSelectionDialog(
              amount: amount,
              transactionId: transactionId,
              transactionCategory: _category, // Pass the selected transaction category
            ),
          );

          if (selectedGoalId != null && mounted) {
            setState(() {
              _addToGoal = true;
              _selectedGoalId = selectedGoalId;
            });
          }
        } else {
          // Uncheck
          setState(() {
            _addToGoal = false;
            _selectedGoalId = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(_addToGoal ? 16 : 12),
        decoration: BoxDecoration(
          color: _addToGoal 
              ? AppColors.accentGreen.withOpacity(0.1)
              : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _addToGoal 
                ? AppColors.accentGreen.withOpacity(0.3)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _addToGoal ? AppColors.accentGreen : Colors.transparent,
                border: Border.all(
                  color: _addToGoal ? AppColors.accentGreen : AppColors.border,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _addToGoal
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to Goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _addToGoal 
                          ? AppColors.accentGreen 
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (_addToGoal && _selectedGoalId != null) ...[
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final goalProvider = context.watch<GoalProvider>();
                        final goal = goalProvider.getGoal(_selectedGoalId!);
                        return Text(
                          goal?.title ?? 'Selected Goal',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.savings,
              color: _addToGoal 
                  ? AppColors.accentGreen 
                  : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    if (widget.existing == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction? This action cannot be undone.'),
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
      final provider = context.read<TransactionProvider>();
      await provider.remove(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final titleText = isEditing
        ? 'Edit Transaction'
        : _type == TransactionType.expense
        ? 'Add Expense'
        : 'Add Income';


    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      resizeToAvoidBottomInset: false, // Prevent UI from moving up with keyboard
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top section: Header and Toggle
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.arrow_back_ios,
                                      color: AppColors.textPrimary),
                                ),
                                Text(
                                  titleText,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                isEditing
                                    ? IconButton(
                                        onPressed: _deleteTransaction,
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        tooltip: 'Delete Transaction',
                                      )
                                    : const SizedBox(width: 48),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Expense / Income toggle
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: AppColors.accentGreen, width: 1),
                              ),
                              child: Row(
                                children: [
                                  _toggleButton(
                                    label: "Expenses",
                                    selected: _type == TransactionType.expense,
                                    onTap: () {
                                      if (_type != TransactionType.expense) {
                                        setState(() {
                                          _type = TransactionType.expense;
                                          _category = 'Others';
                                        });
                                      }
                                    },
                                  ),
                                  _toggleButton(
                                    label: "Income",
                                    selected: _type == TransactionType.income,
                                    onTap: () {
                                      if (_type != TransactionType.income) {
                                        setState(() {
                                          _type = TransactionType.income;
                                          _category = 'Others';
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Center section: Amount and Note
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Amount field
                          Center(
                            child: IntrinsicWidth(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    "₹",
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w300,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: TextFormField(
                                      controller: _amountController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.left,
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                        hintStyle: TextStyle(
                                          color: AppColors.textPrimary.withOpacity(0.5),
                                          fontSize: 36,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        errorBorder: InputBorder.none,
                                        focusedErrorBorder: InputBorder.none,
                                        disabledBorder: InputBorder.none,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Title field
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),

                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 100,
                                  maxWidth: 280,
                                ),
                                child: IntrinsicWidth(
                                  child: TextFormField(
                                    controller: _titleController,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: _makeRecurring ? "Title (Required)" : "Add Title",
                                      hintStyle: TextStyle(
                                        color: _makeRecurring 
                                            ? Colors.orange.withOpacity(0.7)
                                            : Colors.grey,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                    ),
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textCapitalization: TextCapitalization.sentences,
                                    inputFormatters: [LengthLimitingTextInputFormatter(40)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Bottom section: Date, Category, Account, Save Button
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _pickDate,
                                    child: _infoBox(
                                      icon: Icons.calendar_today,
                                      text: DateFormat.MMMd().format(_date),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _pickCategory,
                                    child: _infoBoxSvg(
                                      iconPath: _getCategoryIconPath(_category),
                                      text: _category,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: _pickAccount,
                              child: Builder(
                                builder: (context) {
                                  final accountProvider = context.watch<AccountProvider>();
                                  final selectedAccount = accountProvider.getAccount(_selectedAccountId);
                                  final accountName = selectedAccount?.name ?? 'Cash';
                                  return _infoBox(
                                    icon: Icons.account_balance_wallet,
                                    text: accountName,
                                  );
                                },
                              ),
                            ),
                            // Add to Goal Checkbox (only for income transactions)
                            if (_type == TransactionType.income && FeatureFlags.goalsFeatureEnabled) ...[
                              const SizedBox(height: 16),
                              _buildAddToGoalCheckbox(),
                            ],
                            // Make Recurring Toggle (only for new transactions)
                            if (widget.existing == null && FeatureFlags.recurringTransactionsFeatureEnabled) ...[
                              const SizedBox(height: 16),
                              _buildRecurringToggle(),
                            ],
                            const SizedBox(height: 20),
                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSaving 
                                      ? AppColors.accentGreen.withOpacity(0.6)
                                      : AppColors.accentGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                  titleText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 🔸 Toggle Button
  Widget _toggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.accentGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔸 Info Box for Material Icons
  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.accentGreen, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔸 Info Box for SVG Icons
  Widget _infoBoxSvg({required String iconPath, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            colorFilter: const ColorFilter.mode(
              AppColors.accentGreen,
              BlendMode.srcIn,
            ),
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔸 Recurring Transaction Toggle
  Widget _buildRecurringToggle() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(_makeRecurring ? 16 : 12),
      decoration: BoxDecoration(
        color: _makeRecurring 
            ? AppColors.accentGreen.withOpacity(0.1)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _makeRecurring 
              ? AppColors.accentGreen.withOpacity(0.3)
              : Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.repeat,
                    color: _makeRecurring 
                        ? AppColors.accentGreen 
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Make this recurring',
                    style: TextStyle(
                      color: _makeRecurring 
                          ? AppColors.accentGreen 
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _makeRecurring,
                onChanged: (value) {
                  setState(() {
                    _makeRecurring = value;
                  });
                },
                activeColor: AppColors.accentGreen,
              ),
            ],
          ),
          if (_makeRecurring) ...[
            const SizedBox(height: 12),
            Text(
              'Frequency',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RecurringFrequency.values.map((frequency) {
                final isSelected = _recurringFrequency == frequency;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _recurringFrequency = frequency;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentGreen
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentGreen
                            : AppColors.textSecondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getFrequencyLabel(frequency),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
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
}
