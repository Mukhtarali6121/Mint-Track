import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../common/app_navigator.dart';
import '../common/currency_provider.dart';
import '../common/currency_formatter.dart';
import '../models.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/sms_transaction_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class QuickAddTransactionSheet extends StatefulWidget {
  final DetectedTransaction transaction;

  const QuickAddTransactionSheet({
    super.key,
    required this.transaction,
  });

  static Future<bool?> show(BuildContext context, DetectedTransaction transaction) {
    BuildContext targetContext = context;
    if (Navigator.maybeOf(context) == null) {
      final overlayContext = navigatorKey.currentState?.overlay?.context;
      if (overlayContext != null) {
        targetContext = overlayContext;
      }
    }

    return showModalBottomSheet<bool>(
      context: targetContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickAddTransactionSheet(transaction: transaction),
    );
  }

  @override
  State<QuickAddTransactionSheet> createState() => _QuickAddTransactionSheetState();
}

class _QuickAddTransactionSheetState extends State<QuickAddTransactionSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late TransactionCategory _selectedCategory;
  String _selectedAccountId = 'cash';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.transaction.type;
    _titleController = TextEditingController(text: widget.transaction.title);
    _noteController = TextEditingController(
      text: widget.transaction.smsBody.isNotEmpty
          ? 'Auto-detected from ${widget.transaction.bank}'
          : '',
    );

    _selectedCategory = _guessInitialCategory(widget.transaction.title, _type);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _matchInitialAccount();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TransactionCategory _guessInitialCategory(String title, TransactionType type) {
    final lower = title.toLowerCase();
    if (type == TransactionType.income) {
      if (lower.contains('salary')) return TransactionCategory.salary;
      if (lower.contains('bonus')) return TransactionCategory.bonus;
      if (lower.contains('coupon') || lower.contains('cashback')) return TransactionCategory.coupons;
      return TransactionCategory.others;
    } else {
      if (lower.contains('starbucks') ||
          lower.contains('cafe') ||
          lower.contains('food') ||
          lower.contains('swiggy') ||
          lower.contains('zomato') ||
          lower.contains('restaurant') ||
          lower.contains('tea') ||
          lower.contains('coffee')) {
        return TransactionCategory.foodDining;
      }
      if (lower.contains('amazon') ||
          lower.contains('flipkart') ||
          lower.contains('myntra') ||
          lower.contains('mart') ||
          lower.contains('shop') ||
          lower.contains('store')) {
        return TransactionCategory.shopping;
      }
      if (lower.contains('uber') ||
          lower.contains('ola') ||
          lower.contains('metro') ||
          lower.contains('fuel') ||
          lower.contains('petrol') ||
          lower.contains('irctc') ||
          lower.contains('railway')) {
        return TransactionCategory.travelling;
      }
      if (lower.contains('bill') ||
          lower.contains('electricity') ||
          lower.contains('airtel') ||
          lower.contains('jio') ||
          lower.contains('vi') ||
          lower.contains('wifi') ||
          lower.contains('broadband') ||
          lower.contains('bescom')) {
        return TransactionCategory.billsUtilities;
      }
      if (lower.contains('netflix') ||
          lower.contains('prime') ||
          lower.contains('spotify') ||
          lower.contains('movie') ||
          lower.contains('cinema') ||
          lower.contains('pvr')) {
        return TransactionCategory.entertainment;
      }
      if (lower.contains('pharmacy') ||
          lower.contains('hospital') ||
          lower.contains('clinic') ||
          lower.contains('med') ||
          lower.contains('apollo')) {
        return TransactionCategory.medical;
      }
      return TransactionCategory.foodDining;
    }
  }

  void _matchInitialAccount() {
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final accounts = accountProvider.accounts;
    if (accounts.isEmpty) return;

    final bank = widget.transaction.bank.toLowerCase();
    final accNumber = widget.transaction.account.toLowerCase();

    Account? match;
    for (final a in accounts) {
      final name = a.name.toLowerCase();
      if (bank.isNotEmpty && (name.contains(bank) || bank.contains(name))) {
        match = a;
        break;
      }
      if (accNumber.isNotEmpty && name.contains(accNumber)) {
        match = a;
        break;
      }
    }

    if (match != null) {
      setState(() {
        _selectedAccountId = match!.id;
      });
    } else if (accounts.isNotEmpty) {
      setState(() {
        _selectedAccountId = accounts.first.id;
      });
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description/title'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);

      final newItem = TransactionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: widget.transaction.amount,
        type: _type,
        date: widget.transaction.timestamp,
        category: _selectedCategory.displayName,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        accountId: _selectedAccountId,
      );

      await transactionProvider.add(newItem);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_type == TransactionType.expense ? "Expense" : "Income"} of ₹${widget.transaction.amount.toStringAsFixed(2)} saved!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transaction: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final isExpense = _type == TransactionType.expense;

    final availableCategories = isExpense
        ? TransactionCategoryHelper.getExpenseCategories()
        : TransactionCategoryHelper.getIncomeCategories();

    final formattedAmount = CurrencyFormatter.format(
      amount: widget.transaction.amount,
      symbol: currencyProvider.currencySymbol,
      spaceBetween: true,
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundScaffold,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction Found',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Detected from ${widget.transaction.bank}',
                          style: TextStyle(
                            fontFamily: AppFonts.fontFamily,
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Highlighted Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isExpense ? const Color(0xFFFFF2F0) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpense ? const Color(0xFFFFCCC7) : const Color(0xFFBBF7D0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpense ? const Color(0xFFFF4D4F) : const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isExpense ? 'Debit / Expense' : 'Credit / Income',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(widget.transaction.timestamp),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formattedAmount,
                            style: TextStyle(
                              fontFamily: AppFonts.fontFamily,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: isExpense ? const Color(0xFFCF1322) : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                      if (widget.transaction.account.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.credit_card, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'A/C ending with ${widget.transaction.account}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Description / Title Field
                const Text(
                  'Description / Title *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g. Starbucks, Grocery, Dinner',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _titleController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _titleController.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Category Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _selectedCategory.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Quick Category Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableCategories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final cat = availableCategories[index];
                      final isSelected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat.displayName),
                        selected: isSelected,
                        selectedColor: AppColors.accentGreen,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        avatar: Icon(
                          cat.icon,
                          size: 16,
                          color: isSelected ? Colors.white : cat.color,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? AppColors.accentGreen : AppColors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategory = cat;
                            });
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Account Selection
                if (accountProvider.accounts.isNotEmpty) ...[
                  const Text(
                    'Deposit to / Paid from Account',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: accountProvider.accounts.any((a) => a.id == _selectedAccountId)
                            ? _selectedAccountId
                            : accountProvider.accounts.first.id,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                        items: accountProvider.accounts.map((acc) {
                          return DropdownMenuItem<String>(
                            value: acc.id,
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.accentGreen),
                                const SizedBox(width: 10),
                                Expanded(child: Text(acc.name)),
                                Text(
                                  '₹${acc.balance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            setState(() {
                              _selectedAccountId = newId;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          isExpense ? 'Save Expense' : 'Save Income',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 8),

                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Discard',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
