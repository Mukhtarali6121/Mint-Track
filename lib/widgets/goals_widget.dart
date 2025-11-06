import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/presentation/screens/goals_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../goal_provider.dart';
import '../transaction_provider.dart';
import 'goal_completion_dialog.dart';

class GoalsWidget extends StatefulWidget {
  const GoalsWidget({super.key});

  @override
  State<GoalsWidget> createState() => _GoalsWidgetState();
}

class _GoalsWidgetState extends State<GoalsWidget> {

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final goalProvider = context.watch<GoalProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    // Get active goals (incomplete)
    final activeGoals = goalProvider.getActiveGoals();
    
    // Update progress for all goals and check for newly completed goals
    WidgetsBinding.instance.addPostFrameCallback((_) {
      goalProvider.updateAllProgress(transactionProvider);
      
      // Check for newly completed goals
      for (final goal in goalProvider.goals) {
        if (goal.isCompleted && goal.targetAmount != null) {
          // Show completion dialog after a short delay
          // The dialog class itself handles preventing duplicates
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              GoalCompletionDialog.show(context, goal);
            }
          });
        }
      }
    });

    // Show top 3 active goals
    final displayedGoals = activeGoals.take(3).toList();

    if (displayedGoals.isEmpty) {
      return const SizedBox.shrink(); // Don't show widget if no goals
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.accentGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Goals',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GoalsScreen()),
                  );
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...displayedGoals.map((goal) {
            final isSaving = goal.type == GoalType.saving;
            final hasAmount = goal.targetAmount != null;
            final progress = goal.progressPercentage;
            final isOverLimit = goal.type == GoalType.spendingLimit && 
                               goal.targetAmount != null && 
                               goal.currentAmount > goal.targetAmount!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSaving
                              ? AppColors.accentGreen.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isSaving ? 'Save' : 'Limit',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isSaving ? AppColors.accentGreen : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hasAmount) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${CurrencyFormatter.format(amount: goal.currentAmount, symbol: currencySymbol)} / ${CurrencyFormatter.format(amount: goal.targetAmount!, symbol: currencySymbol)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOverLimit ? Colors.red : AppColors.accentGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: isOverLimit ? 1.0 : progress / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOverLimit ? Colors.red : AppColors.accentGreen,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 4),
                    Text(
                      'No target amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  if (goal != displayedGoals.last) const SizedBox(height: 12),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

