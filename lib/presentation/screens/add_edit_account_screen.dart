import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/premium_provider.dart';
import '../../common/premium_constants.dart';
import 'premium_upgrade_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddEditAccountScreen extends StatefulWidget {
  const AddEditAccountScreen({super.key, this.existing});
  final Account? existing;

  @override
  State<AddEditAccountScreen> createState() => _AddEditAccountScreenState();
}

class _AddEditAccountScreenState extends State<AddEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _initialBalanceController = TextEditingController();
  DateTime _createdAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _initialBalanceController.text = '0.00';
      _createdAt = e.createdAt;
    } else {
      _initialBalanceController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AccountProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    final accountName = _nameController.text.trim();
    final initialBalance = double.tryParse(_initialBalanceController.text.trim()) ?? 0.0;

    if (widget.existing != null) {
      // Update existing account
      final updatedAccount = widget.existing!.copyWith(
        name: accountName,
      );
      await provider.updateAccount(updatedAccount);
    } else {
      // Create new account
      final accountId = DateTime.now().millisecondsSinceEpoch.toString();
      final newAccount = Account(
        id: accountId,
        name: accountName,
        balance: 0.0, // Balance will be calculated from transactions
        createdAt: DateTime.now(),
        userId: userId,
        isSynced: false,
      );

      try {
        await provider.addAccount(newAccount);
      } catch (e) {
        // Handle account limit error
        if (mounted) {
          final errorMessage = e.toString();
          if (errorMessage.contains('limit reached')) {
            // Show upgrade dialog
            _showUpgradeDialog(context, 'Account Limit Reached', 
              'You have reached the limit of ${PremiumConstants.FREE_MAX_ACCOUNTS} accounts. Upgrade to Premium for unlimited accounts.');
          } else {
            Fluttertoast.showToast(msg: errorMessage, backgroundColor: Colors.red);
          }
        }
        return;
      }

      // If initial balance is provided, create an income transaction
      if (initialBalance > 0) {
        final incomeTransaction = TransactionItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: 'Initial Balance',
          amount: initialBalance,
          type: TransactionType.income,
          date: DateTime.now(),
          category: 'Others',
          accountId: accountId,
          note: 'Initial balance for ${accountName}',
        );
        await transactionProvider.add(incomeTransaction);
      }
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final titleText = isEditing ? 'Edit Account' : 'Add Account';

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
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Account Name Field
                Text(
                  'Account Name',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Cash, Bank Account, Friend\'s Account',
                    hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Enter account name';
                    if (t.length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Initial Balance Field (only for new accounts)
                if (!isEditing) ...[
                  Text(
                    'Initial Balance (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add an initial balance for this account (e.g., when a friend gives you money)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _initialBalanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.grey.withOpacity(0.7)),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isNotEmpty) {
                        final d = double.tryParse(t);
                        if (d == null || d < 0) return 'Enter valid amount';
                      }
                      return null;
                    },
                  ),
                ],
                const Spacer(),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      isEditing ? 'Update Account' : 'Create Account',
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
        ),
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
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
                  MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upgrade'),
            ),
          ],
        );
      },
    );
  }
}

