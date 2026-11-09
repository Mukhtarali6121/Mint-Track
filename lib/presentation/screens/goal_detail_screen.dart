import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/goal.dart';
import '../../models/goal_contribution.dart';
import '../../providers/goal_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../common/currency_formatter.dart';
import '../../common/currency_provider.dart';
import '../../common/goal_contribution_hive_storage.dart';
import '../../theme/app_colors.dart';
import 'add_edit_goal_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({
    super.key,
    required this.goal,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize animation with current progress (only for goals with target amounts)
    if (widget.goal.targetAmount != null) {
      final initialProgress = (widget.goal.progressPercentage / 100).clamp(0.0, 1.0);
      _progressAnimation = Tween<double>(
        begin: 0.0,
        end: initialProgress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
    } else {
      // For goals without target, use a static animation
      _progressAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutCubic,
      ));
    }
    
    // Animate progress on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateProgress();
    });
  }

  void _updateProgress() {
    final goalProvider = context.read<GoalProvider>();
    final transactionProvider = context.read<TransactionProvider>();
    goalProvider.calculateProgress(widget.goal, transactionProvider);
    
    final goal = goalProvider.getGoal(widget.goal.id);
    if (goal != null && mounted) {
      // Only animate progress for goals with target amounts
      if (goal.targetAmount != null) {
        final progress = (goal.progressPercentage / 100).clamp(0.0, 1.0);
        _progressAnimation = Tween<double>(
          begin: 0.0,
          end: progress,
        ).animate(CurvedAnimation(
          parent: _progressController,
          curve: Curves.easeOutCubic,
        ));
        _progressController.reset();
        _progressController.forward();
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final currencySymbol = currencyProvider.currencySymbol;
    final goalProvider = context.watch<GoalProvider>();
    final transactionProvider = context.watch<TransactionProvider>();

    // Calculate progress
    goalProvider.calculateProgress(widget.goal, transactionProvider);
    final goal = goalProvider.getGoal(widget.goal.id) ?? widget.goal;

    final hasAmount = goal.targetAmount != null;
    final progress = goal.progressPercentage;
    final goalIsCompleted = goal.isCompleted || (hasAmount && goal.currentAmount >= goal.targetAmount!);
    final remainingAmount = hasAmount ? (goal.targetAmount! - goal.currentAmount) : 0.0;

    // Get contributions for this goal
    final contributions = GoalContributionHiveStorage.getContributionsForGoal(goal.id);

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          goal.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditGoalScreen(goal: goal),
                ),
              ).then((_) {
                // Refresh when returning from edit
                setState(() {
                  _updateProgress();
                });
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Fixed Header Section with Circular Progress
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 24,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accentGreen,
                  AppColors.accentGreen.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),

                  // Circular Progress Indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                        ),
                      ),
                      // Animated progress circle - show for goals with target, or a static circle for goals without target
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: hasAmount
                            ? AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return CircularProgressIndicator(
                                    value: _progressAnimation.value,
                                    strokeWidth: 12,
                                    backgroundColor: Colors.transparent,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                  );
                                },
                              )
                            : CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: 12,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                      ),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasAmount)
                            Text(
                              '${progress.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -2,
                              ),
                            ),
                          if (!hasAmount)
                            Text(
                              'No Target',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.format(
                              amount: goal.currentAmount,
                              symbol: currencySymbol,
                              decimalDigits: 0,
                            ),
                            style: TextStyle(
                              fontSize: hasAmount ? 18 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (!hasAmount)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Contributed',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Amount Details
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: hasAmount
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Target',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(
                                      amount: goal.targetAmount!,
                                      symbol: currencySymbol,
                                      decimalDigits: 0,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.3),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Remaining',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(
                                      amount: remainingAmount > 0 ? remainingAmount : 0.0,
                                      symbol: currencySymbol,
                                      decimalDigits: 0,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Text(
                                'Total Contributed',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(
                                  amount: goal.currentAmount,
                                  symbol: currencySymbol,
                                  decimalDigits: 0,
                                ),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                    ),
                ],
              ),
            ),
          
          // Scrollable Content Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: goalIsCompleted
                          ? AppColors.accentGreen.withOpacity(0.1)
                          : AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (goalIsCompleted) ...[
                          const Text('🎉', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          goalIsCompleted ? 'Goal Reached!' : 'In Progress',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: goalIsCompleted
                                ? AppColors.accentGreen
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Goal Information
                  Text(
                    'Goal Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.calendar_today,
                    label: 'Created',
                    value: DateFormat('MMM dd, yyyy').format(goal.createdAt),
                  ),
                  if (goal.deadline != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      icon: Icons.event,
                      label: 'Deadline',
                      value: DateFormat('MMM dd, yyyy').format(goal.deadline!),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Contributions Section
                  if (contributions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Contributions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${contributions.length} ${contributions.length == 1 ? 'contribution' : 'contributions'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...contributions.take(10).map((contribution) => _buildContributionCard(
                      contribution,
                      currencySymbol,
                    )),
                    if (contributions.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'And ${contributions.length - 10} more contributions...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.savings_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No contributions yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add income and allocate it to this goal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionCard(GoalContribution contribution, String currencySymbol) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_circle_outline,
              color: AppColors.accentGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.format(
                    amount: contribution.amount,
                    symbol: currencySymbol,
                    decimalDigits: 0,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy').format(contribution.date),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

