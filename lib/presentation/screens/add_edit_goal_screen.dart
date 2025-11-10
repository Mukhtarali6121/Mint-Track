import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/widgets/category_picker.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/account_provider.dart';
import '../../models.dart';

class AddEditGoalScreen extends StatefulWidget {
  const AddEditGoalScreen({super.key, this.goal});
  final Goal? goal;

  @override
  State<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends State<AddEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();
  
  GoalType _type = GoalType.saving;
  bool _hasTargetAmount = false;
  DateTime? _deadline;
  String? _selectedCategoryId;
  String? _selectedAccountId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.goal;
    if (existing != null) {
      _titleController.text = existing.title;
      _type = existing.type;
      _hasTargetAmount = existing.targetAmount != null;
      if (existing.targetAmount != null) {
        _targetAmountController.text = existing.targetAmount!.toStringAsFixed(2);
      }
      _deadline = existing.deadline;
      _selectedCategoryId = existing.categoryId;
      _selectedAccountId = existing.accountId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _deadline ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _pickCategory() async {
    final transactionType = _type == GoalType.saving 
        ? TransactionType.income 
        : TransactionType.expense;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CategoryPickerBottomSheet(
        transactionType: transactionType,
        selectedCategory: _selectedCategoryId,
        onCategorySelected: (category) {
          setState(() => _selectedCategoryId = category);
        },
      ),
    );
  }

  Future<void> _pickAccount() async {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;
    
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts available')),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...accounts.map((account) => ListTile(
              title: Text(account.name),
              onTap: () => Navigator.pop(context, account.id),
            )),
            ListTile(
              title: const Text('All Accounts'),
              leading: const Icon(Icons.all_inclusive),
              onTap: () => Navigator.pop(context, null),
            ),
          ],
        ),
      ),
    );
    
    if (selected != null) {
      setState(() => _selectedAccountId = selected);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    try {
      final goalProvider = context.read<GoalProvider>();
      
      // Ensure provider is initialized
      if (!goalProvider.isInitialized) {
        await goalProvider.initialize();
      }
      
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      final title = _titleController.text.trim();
      final targetAmount = _hasTargetAmount && _targetAmountController.text.isNotEmpty
          ? double.tryParse(_targetAmountController.text.trim())
          : null;

      if (widget.goal != null) {
        // Update existing goal
        final updatedGoal = widget.goal!.copyWith(
          title: title,
          type: _type,
          targetAmount: targetAmount,
          deadline: _deadline,
          categoryId: _selectedCategoryId,
          accountId: _selectedAccountId,
          isSynced: false, // Mark as unsynced after update
        );
        await goalProvider.updateGoal(updatedGoal);
      } else {
        // Create new goal
        final goalId = DateTime.now().millisecondsSinceEpoch.toString();
        final newGoal = Goal(
          id: goalId,
          title: title,
          type: _type,
          targetAmount: targetAmount,
          currentAmount: 0.0,
          deadline: _deadline,
          categoryId: _selectedCategoryId,
          accountId: _selectedAccountId,
          isCompleted: false,
          createdAt: DateTime.now(),
          userId: userId,
          isSynced: false,
        );
        await goalProvider.addGoal(newGoal);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = Provider.of<CurrencyProvider>(context).currencySymbol;
    final isEditing = widget.goal != null;
    final titleText = isEditing ? 'Edit Goal' : 'Add Goal';

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          titleText,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                Text(
                  'Goal Title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Save for vacation, Limit dining out',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Enter goal title';
                    if (t.length < 3) return 'Title must be at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Type Selector
                Text(
                  'Goal Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _type = GoalType.saving),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _type == GoalType.saving
                                ? AppColors.accentGreen.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == GoalType.saving
                                  ? AppColors.accentGreen
                                  : Colors.grey.withOpacity(0.2),
                              width: _type == GoalType.saving ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.savings,
                                color: _type == GoalType.saving
                                    ? AppColors.accentGreen
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Saving Goal',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _type == GoalType.saving
                                      ? AppColors.accentGreen
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _type = GoalType.spendingLimit),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _type == GoalType.spendingLimit
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == GoalType.spendingLimit
                                  ? Colors.orange
                                  : Colors.grey.withOpacity(0.2),
                              width: _type == GoalType.spendingLimit ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.trending_down,
                                color: _type == GoalType.spendingLimit
                                    ? Colors.orange
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Spending Limit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _type == GoalType.spendingLimit
                                      ? Colors.orange
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Target Amount Toggle
                Row(
                  children: [
                    Checkbox(
                      value: _hasTargetAmount,
                      onChanged: (value) {
                        setState(() {
                          _hasTargetAmount = value ?? false;
                          if (!_hasTargetAmount) {
                            _targetAmountController.clear();
                          }
                        });
                      },
                      activeColor: AppColors.accentGreen,
                    ),
                    Expanded(
                      child: Text(
                        'Set target amount',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_hasTargetAmount) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _targetAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                      prefixText: '$currencySymbol ',
                      prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentGreen, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (_hasTargetAmount) {
                        final t = v?.trim() ?? '';
                        if (t.isEmpty) return 'Enter target amount';
                        final d = double.tryParse(t);
                        if (d == null || d <= 0) return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),

                // Deadline
                Text(
                  'Deadline (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          _deadline != null
                              ? DateFormat('MMM dd, yyyy').format(_deadline!)
                              : 'Select deadline',
                          style: TextStyle(
                            color: _deadline != null
                                ? AppColors.textPrimary
                                : Colors.grey.withOpacity(0.7),
                          ),
                        ),
                        const Spacer(),
                        if (_deadline != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _deadline = null),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Category Filter (Optional)
                Text(
                  'Category Filter (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickCategory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedCategoryId ?? 'All categories',
                            style: TextStyle(
                              color: _selectedCategoryId != null
                                  ? AppColors.textPrimary
                                  : Colors.grey.withOpacity(0.7),
                            ),
                          ),
                        ),
                        if (_selectedCategoryId != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _selectedCategoryId = null),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Account Filter (Optional)
                Text(
                  'Account Filter (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickAccount,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet, color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Consumer<AccountProvider>(
                            builder: (context, accountProvider, _) {
                              final accountName = _selectedAccountId != null
                                  ? accountProvider.getAccount(_selectedAccountId!)?.name ?? 'All Accounts'
                                  : 'All Accounts';
                              return Text(
                                accountName,
                                style: TextStyle(
                                  color: _selectedAccountId != null
                                      ? AppColors.textPrimary
                                      : Colors.grey.withOpacity(0.7),
                                ),
                              );
                            },
                          ),
                        ),
                        if (_selectedAccountId != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () => setState(() => _selectedAccountId = null),
                            color: AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isEditing ? 'Update Goal' : 'Create Goal',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

