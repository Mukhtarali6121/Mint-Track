import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/presentation/screens/add_edit_goal_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../goal_provider.dart';
import '../../transaction_provider.dart';
import '../../widgets/goal_completion_dialog.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  GoalType? _selectedFilter;

  Future<void> _deleteGoal(BuildContext context, Goal goal) async {
    // Get provider and scaffold messenger references before async operation
    final provider = context.read<GoalProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Are you sure you want to delete "${goal.title}"? This action cannot be undone.'),
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

    if (confirmed == true && mounted) {
      await provider.removeGoal(goal.id);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Goal "${goal.title}" deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildGoalCard(BuildContext context, Goal goal, String currencySymbol) {
    final goalProvider = context.read<GoalProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    
    // Calculate progress
    goalProvider.calculateProgress(goal, transactionProvider);
    
    final isSaving = goal.type == GoalType.saving;
    final hasAmount = goal.targetAmount != null;
    final progress = goal.progressPercentage;
    final isOverLimit = goal.type == GoalType.spendingLimit && 
                       goal.targetAmount != null && 
                       goal.currentAmount > goal.targetAmount!;
    
    // Check if goal is "locked" (target achieved - cannot be marked incomplete)
    final isTargetAchieved = goal.targetAmount != null && 
                            goal.currentAmount >= goal.targetAmount!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditGoalScreen(goal: goal),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSaving
                                    ? AppColors.accentGreen.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isSaving ? 'Saving' : 'Spending Limit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isSaving
                                      ? AppColors.accentGreen
                                      : Colors.orange,
                                ),
                              ),
                            ),
                            if (goal.isCompleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Completed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle completion checkbox
                      // Disable checkbox if target is achieved (goal is locked as completed)
                      Checkbox(
                        value: goal.isCompleted,
                        onChanged: isTargetAchieved 
                            ? null // Disable if target achieved
                            : (value) async {
                                final goalProvider = context.read<GoalProvider>();
                                final wasCompleted = goal.isCompleted;
                                final isNowCompleted = value ?? false;
                                
                                final updatedGoal = goal.copyWith(
                                  isCompleted: isNowCompleted,
                                  isSynced: false, // Mark as unsynced after manual change
                                );
                                await goalProvider.updateGoal(updatedGoal);
                                
                                // Show congratulations dialog if goal was just completed
                                if (!wasCompleted && isNowCompleted && mounted) {
                                  Future.delayed(const Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      GoalCompletionDialog.show(context, updatedGoal);
                                    }
                                  });
                                }
                              },
                        activeColor: AppColors.accentGreen,
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => AddEditGoalScreen(goal: goal),
                                      ),
                                    );
                                  },
                                ),
                                // Only show completion toggle option if target is not achieved
                                // Goals that reached their target are locked as completed
                                if (!isTargetAchieved)
                                  ListTile(
                                    leading: Icon(
                                      goal.isCompleted ? Icons.check_circle_outline : Icons.check_circle,
                                      color: goal.isCompleted ? Colors.grey : AppColors.accentGreen,
                                    ),
                                    title: Text(goal.isCompleted ? 'Mark as Incomplete' : 'Mark as Completed'),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      final goalProvider = context.read<GoalProvider>();
                                      final wasCompleted = goal.isCompleted;
                                      final isNowCompleted = !goal.isCompleted;
                                      
                                      final updatedGoal = goal.copyWith(
                                        isCompleted: isNowCompleted,
                                        isSynced: false, // Mark as unsynced after manual change
                                      );
                                      await goalProvider.updateGoal(updatedGoal);
                                      
                                      // Show congratulations dialog if goal was just completed
                                      if (!wasCompleted && isNowCompleted && mounted) {
                                        Future.delayed(const Duration(milliseconds: 300), () {
                                          if (mounted) {
                                            GoalCompletionDialog.show(context, updatedGoal);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ListTile(
                                  leading: const Icon(Icons.delete, color: Colors.red),
                                  title: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _deleteGoal(context, goal);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (hasAmount) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${CurrencyFormatter.format(amount: goal.currentAmount, symbol: currencySymbol)} / ${CurrencyFormatter.format(amount: goal.targetAmount!, symbol: currencySymbol)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isOverLimit ? Colors.red : AppColors.accentGreen,
                          ),
                        ),
                        if (goal.remainingAmount != null && !isOverLimit)
                          Text(
                            '${CurrencyFormatter.format(amount: goal.remainingAmount!, symbol: currencySymbol)} left',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (isOverLimit)
                          Text(
                            'Over limit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: isOverLimit ? 1.0 : progress / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOverLimit ? Colors.red : AppColors.accentGreen,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'No target amount set',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (goal.deadline != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Deadline: ${DateFormat('MMM dd, yyyy').format(goal.deadline!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final String currencySymbol = currencyProvider.currencySymbol;
    final goalProvider = context.watch<GoalProvider>();
    final transactionProvider = context.watch<TransactionProvider>();
    
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

    List<Goal> displayedGoals = _selectedFilter == null
        ? goalProvider.goals
        : goalProvider.goals.where((g) => g.type == _selectedFilter).toList();

    // Separate active and completed
    final activeGoals = displayedGoals.where((g) => !g.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final completedGoals = displayedGoals.where((g) => g.isCompleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        title: const Text(
          'Goals',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<GoalType?>(
            icon: const Icon(Icons.filter_list, color: AppColors.textPrimary),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Goals'),
              ),
              const PopupMenuItem(
                value: GoalType.saving,
                child: Text('Saving Goals'),
              ),
              const PopupMenuItem(
                value: GoalType.spendingLimit,
                child: Text('Spending Limits'),
              ),
            ],
          ),
        ],
      ),
      body: displayedGoals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No goals yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first goal to start tracking',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activeGoals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Active Goals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...activeGoals.map((goal) => _buildGoalCard(context, goal, currencySymbol)),
                  ],
                  if (completedGoals.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Completed Goals',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...completedGoals.map((goal) => _buildGoalCard(context, goal, currencySymbol)),
                  ],
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditGoalScreen(),
            ),
          );
        },
        backgroundColor: AppColors.accentGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

