import 'package:expense_tracker/common/currency_formatter.dart';
import 'package:expense_tracker/common/currency_provider.dart';
import 'package:expense_tracker/models/goal.dart';
import 'package:expense_tracker/presentation/screens/add_edit_goal_screen.dart';
import 'package:expense_tracker/presentation/screens/goal_detail_screen.dart';
import 'package:expense_tracker/presentation/screens/premium_upgrade_screen.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:expense_tracker/theme/app_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/goal_completion_dialog.dart';

class GoalsScreenNew extends StatefulWidget {
  const GoalsScreenNew({super.key});

  @override
  State<GoalsScreenNew> createState() => _GoalsScreenNewState();
}

class _GoalsScreenNewState extends State<GoalsScreenNew> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, _) {
        // Check if user has premium access
        if (!premiumProvider.isPremium) {
          return _buildPremiumRequiredView();
        }
        
        return _buildGoalsScreen(context);
      },
    );
  }

  Widget _buildGoalsScreen(BuildContext context) {
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
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              GoalCompletionDialog.show(context, goal);
            }
          });
        }
      }
    });

    // Get saving goals (not spending limits) - separate active and completed
    final allSavingGoals = goalProvider.goals
        .where((g) => g.type == GoalType.saving)
        .toList();
    
    final activeSavingGoals = allSavingGoals
        .where((g) => !g.isCompleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    final completedSavingGoals = allSavingGoals
        .where((g) => g.isCompleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Check if there are any goals
    final hasAnyGoals = allSavingGoals.isNotEmpty;

    // Calculate total savings (only from active goals) - based on contributions
    double totalSavings = 0.0;
    double totalTarget = 0.0;
    for (final goal in activeSavingGoals) {
      if (goal.targetAmount != null) {
        // currentAmount is already calculated from contributions in calculateProgress
        totalSavings += goal.currentAmount;
        totalTarget += goal.targetAmount!;
      }
    }

    final totalProgress = totalTarget > 0 ? (totalSavings / totalTarget * 100).clamp(0.0, 100.0) : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8F9F8), Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Goals',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Save for your dreams',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show + icon only when there are goals
                    if (hasAnyGoals)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.accentGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddEditGoalScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),

                      // Empty State - Show when there are NO goals
                      if (!hasAnyGoals) ...[
                        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                        // Empty State Image with better styling
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            child: SvgPicture.asset(
                              'assets/images/goal_screen.svg',
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: MediaQuery.of(context).size.width * 0.7,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Title and Description
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Start Your Savings Journey',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Set financial goals and track your progress. Every step counts towards your dreams.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      // Total Savings Card - Show only when there are goals
                      if (hasAnyGoals)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.accentGreen.withOpacity(0.9),
                                AppColors.accentGreen,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGreen.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Savings',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        CurrencyFormatter.format(
                                          amount: totalSavings,
                                          symbol: currencySymbol,
                                          decimalDigits: 0,
                                          spaceBetween: true,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.track_changes,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                              if (totalTarget > 0) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'You\'ve reached ${totalProgress.toStringAsFixed(0)}% of your total goal target.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      if (hasAnyGoals) const SizedBox(height: 24),

                      // Active Goals Section
                      if (activeSavingGoals.isNotEmpty) ...[
                        Text(
                          'Active Goals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...activeSavingGoals.map((goal) => _buildGoalCard(context, goal, currencySymbol, isCompleted: false)),
                        const SizedBox(height: 24),
                      ],

                      // Completed Goals Section
                      if (completedSavingGoals.isNotEmpty) ...[
                        Text(
                          'Completed Goals',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...completedSavingGoals.map((goal) => _buildGoalCard(context, goal, currencySymbol, isCompleted: true)),
                        const SizedBox(height: 24),
                      ],

                      // Create New Goal Card - Show only when there are NO goals
                      if (!hasAnyGoals)
                        Center(
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AddEditGoalScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.accentGreen.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.accentGreen.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: AppColors.accentGreen,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Create Your First Goal',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Tap to get started',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGoal(BuildContext context, Goal goal) async {
    final provider = context.read<GoalProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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

  Widget _buildGoalCard(BuildContext context, Goal goal, String currencySymbol, {bool isCompleted = false}) {
    final goalProvider = context.watch<GoalProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    // Get updated goal from provider - progress is already calculated by updateAllProgress in addPostFrameCallback
    // We use the goal from the provider's list which has the updated currentAmount
    final updatedGoal = goalProvider.getGoal(goal.id) ?? goal;

    final hasAmount = updatedGoal.targetAmount != null;
    final progress = updatedGoal.progressPercentage;
    // Use passed parameter or calculate from goal state
    final goalIsCompleted = isCompleted || updatedGoal.isCompleted || (hasAmount && updatedGoal.currentAmount >= updatedGoal.targetAmount!);

    // Get icon based on goal title or use default
    IconData goalIcon = Icons.savings_outlined;
    if (goal.title.toLowerCase().contains('emergency')) {
      goalIcon = Icons.shield_outlined;
    } else if (goal.title.toLowerCase().contains('trip') || goal.title.toLowerCase().contains('travel')) {
      goalIcon = Icons.flight_outlined;
    } else if (goal.title.toLowerCase().contains('macbook') || goal.title.toLowerCase().contains('laptop')) {
      goalIcon = Icons.laptop_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: goalIsCompleted
                    ? AppColors.accentGreen.withOpacity(0.15)
                    : AppColors.accentGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                goalIsCompleted ? Icons.check_circle : goalIcon,
                color: goalIsCompleted ? AppColors.accentGreen : AppColors.accentGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Goal Info
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GoalDetailScreen(goal: updatedGoal),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      updatedGoal.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (hasAmount)
                    Text(
                      'Target: ${CurrencyFormatter.format(amount: updatedGoal.targetAmount!, symbol: currencySymbol, decimalDigits: 0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (!hasAmount && updatedGoal.currentAmount > 0)
                    Text(
                      'Contributed: ${CurrencyFormatter.format(amount: updatedGoal.currentAmount, symbol: currencySymbol, decimalDigits: 0)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (hasAmount) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.border.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                goalIsCompleted ? AppColors.accentGreen : AppColors.accentGreen,
                              ),
                            ),
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
                  ],]
                ),
              ),
            ),

            // Amount and Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      CurrencyFormatter.format(
                        amount: updatedGoal.currentAmount,
                        symbol: currencySymbol,
                        decimalDigits: 0,
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: goalIsCompleted ? AppColors.accentGreen : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 20,
                      icon: Icon(
                        Icons.more_vert,
                        color: AppColors.textSecondary.withOpacity(0.7),
                        size: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (value) async {
                        if (value == 'edit') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditGoalScreen(goal: updatedGoal),
                            ),
                          );
                        } else if (value == 'toggle_complete') {
                          final goalProvider = context.read<GoalProvider>();
                          final wasCompleted = updatedGoal.isCompleted;
                          final isNowCompleted = !updatedGoal.isCompleted;
                          
                          final toggledGoal = updatedGoal.copyWith(
                            isCompleted: isNowCompleted,
                            isSynced: false, // Mark as unsynced after manual change
                          );
                          await goalProvider.updateGoal(toggledGoal);
                          
                          // Show congratulations dialog if goal was just completed
                          if (!wasCompleted && isNowCompleted && mounted) {
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) {
                                GoalCompletionDialog.show(context, toggledGoal);
                              }
                            });
                          }
                        } else if (value == 'delete') {
                          _deleteGoal(context, updatedGoal);
                        }
                      },
                      itemBuilder: (context) {
                        // Check if goal has reached target (locked as completed)
                        final hasReachedTarget = hasAmount && updatedGoal.currentAmount >= updatedGoal.targetAmount!;
                        
                        return [
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
                          // Only show completion toggle if target is not achieved
                          // Goals that reached their target are locked as completed
                          if (!hasReachedTarget)
                          PopupMenuItem(
                            value: 'toggle_complete',
                            child: Row(
                              children: [
                                Icon(
                                  updatedGoal.isCompleted ? Icons.check_circle_outline : Icons.check_circle,
                                  color: updatedGoal.isCompleted ? Colors.grey : AppColors.accentGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(updatedGoal.isCompleted ? 'Mark as Incomplete' : 'Mark as Completed'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: goalIsCompleted
                        ? AppColors.accentGreen.withOpacity(0.15)
                        : AppColors.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (goalIsCompleted) ...[
                        const Text(
                          '🎉',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        goalIsCompleted ? 'Goal Reached!' : 'In Progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: goalIsCompleted ? AppColors.accentGreen : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildPremiumRequiredView() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundScaffold,
              AppColors.accentGreen.withOpacity(0.05),
              AppColors.backgroundScaffold,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Goals',
                        style: AppFonts.appBarTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Premium Badge with Star
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.accentGreen,
                                AppColors.accentGreen.withOpacity(0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGreen.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                              Positioned(
                                bottom: 15,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Title
                        Text(
                          'Unlock Premium Goals',
                          style: AppFonts.displayMedium.copyWith(
                            fontWeight: AppFonts.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        // Subtitle
                        Text(
                          'Track your savings targets and achieve your financial dreams',
                          style: AppFonts.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        // Features List
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildFeatureItem(
                                icon: Icons.flag_rounded,
                                text: 'Set multiple savings goals',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                icon: Icons.track_changes_rounded,
                                text: 'Track progress in real-time',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                icon: Icons.celebration_rounded,
                                text: 'Celebrate when you reach targets',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                icon: Icons.insights_rounded,
                                text: 'Get insights on your savings',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Upgrade Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                AppColors.accentGreen,
                                AppColors.accentGreen.withOpacity(0.8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGreen.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PremiumUpgradeScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Upgrade to Premium',
                                  style: AppFonts.buttonText.copyWith(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: AppFonts.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Trial Info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accentGreen.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.celebration_rounded,
                                size: 20,
                                color: AppColors.accentGreen,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '7-day free trial • Cancel anytime',
                                style: AppFonts.bodySmall.copyWith(
                                  color: AppColors.accentGreen,
                                  fontWeight: AppFonts.medium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.accentGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppFonts.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

