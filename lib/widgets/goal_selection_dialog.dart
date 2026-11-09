import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/goal_provider.dart';

class GoalSelectionDialog extends StatelessWidget {
  final double amount;
  final String transactionId;
  final String? transactionCategory; // Category of the transaction being added

  const GoalSelectionDialog({
    super.key,
    required this.amount,
    required this.transactionId,
    this.transactionCategory,
  });

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final goalProvider = context.watch<GoalProvider>();

    // Get only active saving goals (not completed, not spending limits)
    // Filter by category: show goals with no category filter OR goals matching the transaction category
    final availableGoals = goalProvider.goals
        .where((g) {
          // Must be a saving goal and not completed
          if (g.type != GoalType.saving || g.isCompleted) return false;
          
          // If goal has no category filter, it matches all categories
          if (g.categoryId == null || g.categoryId!.isEmpty) return true;
          
          // If transaction has no category, only show goals with no category filter
          if (transactionCategory == null || transactionCategory!.isEmpty) {
            return g.categoryId == null || g.categoryId!.isEmpty;
          }
          
          // Match if goal's categoryId matches transaction category
          return g.categoryId == transactionCategory;
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (availableGoals.isEmpty) {
      // Check if there are any goals at all (to show different message)
      final allSavingGoals = goalProvider.goals
          .where((g) => g.type == GoalType.saving && !g.isCompleted)
          .toList();
      
      final hasGoalsButNoMatch = allSavingGoals.isNotEmpty && 
          transactionCategory != null && 
          transactionCategory!.isNotEmpty;
      
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                hasGoalsButNoMatch ? 'No Matching Goals' : 'No Active Goals',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasGoalsButNoMatch
                    ? 'No goals match the "$transactionCategory" category. Create a goal with this category or one without a category filter.'
                    : 'Create a savings goal first to add contributions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.savings,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Goal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(
                            amount: amount,
                            symbol: currencySymbol,
                            decimalDigits: 0,
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            // Goals List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: availableGoals.length,
                itemBuilder: (context, index) {
                  final goal = availableGoals[index];
                  final progress = goal.progressPercentage;
                  final hasAmount = goal.targetAmount != null;

                  return InkWell(
                    onTap: () => Navigator.of(context).pop(goal.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                          if (hasAmount) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${CurrencyFormatter.format(amount: goal.currentAmount, symbol: currencySymbol, decimalDigits: 0)} / ${CurrencyFormatter.format(amount: goal.targetAmount!, symbol: currencySymbol, decimalDigits: 0)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress / 100,
                                          minHeight: 6,
                                          backgroundColor: AppColors.border.withOpacity(0.3),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.accentGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${progress.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'No target amount',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

