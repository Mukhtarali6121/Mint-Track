import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class GoalCompletionDialog extends StatelessWidget {
  final Goal goal;

  // Shared set to track which goals have shown completion dialog
  // This prevents duplicate dialogs when multiple widgets detect completion
  static final Set<String> _shownCompletionDialogs = {};

  const GoalCompletionDialog({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final isSpendingLimit = goal.type == GoalType.spendingLimit;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentGreen,
              AppColors.accentGreen.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            const Text(
              '🎉 Congratulations! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Goal Title
            Text(
              goal.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Completion Message
            Text(
              isSpendingLimit
                  ? 'You\'ve reached your spending limit!'
                  : 'You\'ve achieved your saving goal!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            // Amount Card (only show if goal has target amount)
            if (goal.targetAmount != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Target Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(
                        amount: goal.targetAmount!,
                        symbol: currencySymbol,
                      ),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> show(BuildContext context, Goal goal) async {
    // Check if we've already shown this dialog
    if (_shownCompletionDialogs.contains(goal.id)) {
      return; // Already shown, don't show again
    }

    // Mark as shown before displaying
    _shownCompletionDialogs.add(goal.id);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => GoalCompletionDialog(goal: goal),
    );
  }

  /// Clear the shown dialogs set (useful for testing or reset)
  static void clearShownDialogs() {
    _shownCompletionDialogs.clear();
  }
}

