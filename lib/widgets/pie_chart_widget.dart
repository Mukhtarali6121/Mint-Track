import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models.dart';
import '../services/chart_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../common/currency_formatter.dart';
import 'custom_donut_chart.dart';

class PieChartWidget extends StatefulWidget {
  final List<TransactionItem> transactions;
  final DateTime selectedMonth;
  final bool isExpenseView;
  final Function(bool) onViewToggle;
  final String currencySymbol;

  const PieChartWidget({
    super.key,
    required this.transactions,
    required this.selectedMonth,
    required this.isExpenseView,
    required this.onViewToggle,
    required this.currencySymbol,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late AnimationController _toggleController;
  late Animation<double> _toggleAnimation;
  int? _selectedCategoryIndex;

  // Curated modern palette with distinctly contrasting hues
  static const List<Color> _modernDonutColors = [
    Color(0xFFFF5722), // 1. Vibrant Coral / Orange
    Color(0xFF29B6F6), // 2. Bright Sky Blue
    Color(0xFF8BC34A), // 3. Fresh Lime Green
    Color(0xFFAB47BC), // 4. Rich Purple
    Color(0xFFFFB300), // 5. Golden Amber
    Color(0xFF00BFA5), // 6. Emerald / Teal
    Color(0xFFEC407A), // 7. Hot Pink
    Color(0xFF3F51B5), // 8. Deep Indigo
    Color(0xFFFF7043), // 9. Warm Tangerine
    Color(0xFF26A69A), // 10. Mint Teal
    Color(0xFF7E57C2), // 11. Violet
    Color(0xFF66BB6A), // 12. Leaf Green
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    // Toggle switch animation (0.0 = Expense, 1.0 = Income)
    _toggleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: widget.isExpenseView ? 0.0 : 1.0,
    );
    _toggleAnimation = CurvedAnimation(
      parent: _toggleController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant PieChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonth != widget.selectedMonth ||
        oldWidget.isExpenseView != widget.isExpenseView) {
      _selectedCategoryIndex = null;
      _animationController.reset();
      _animationController.forward();
    }
    if (oldWidget.isExpenseView != widget.isExpenseView) {
      if (widget.isExpenseView) {
        _toggleController.reverse();
      } else {
        _toggleController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _toggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = widget.isExpenseView
        ? ChartDataService.getExpenseBreakdownByCategory(
            widget.transactions,
            widget.selectedMonth,
          )
        : ChartDataService.getIncomeBreakdownByCategory(
            widget.transactions,
            widget.selectedMonth,
          );

    if (categoryData.isEmpty) {
      return _buildEmptyState();
    }

    final totalAmount = categoryData.values.fold(
      0.0,
      (sum, amount) => sum + amount,
    );
    final segments = _buildDonutSegments(categoryData, totalAmount);

    if (segments.isEmpty) {
      return _buildEmptyState();
    }

    // Keep selected index in bound
    if (_selectedCategoryIndex != null &&
        _selectedCategoryIndex! >= segments.length) {
      _selectedCategoryIndex = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(totalAmount),
          const SizedBox(height: 12),

          // Interactive Donut Chart with Callout Labels
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomDonutChart(
                segments: segments,
                animationProgress: _animation.value,
                selectedIndex: _selectedCategoryIndex,
                currencySymbol: widget.currencySymbol,
                totalAmount: totalAmount,
                onSegmentSelected: (index) {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double totalAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isExpenseView ? 'Expense Breakdown' : 'Income Breakdown',
              style: AppFonts.titleMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(
                amount: totalAmount,
                symbol: widget.currencySymbol,
                decimalDigits: 0,
                spaceBetween: false,
              ),
              style: AppFonts.displaySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        // Animated sliding switch for Expense / Income
        GestureDetector(
          onTap: () {
            widget.onViewToggle(!widget.isExpenseView);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 154,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(3),
            child: AnimatedBuilder(
              animation: _toggleAnimation,
              builder: (context, child) {
                // _toggleAnimation.value: 0.0 = Expense (Left), 1.0 = Income (Right)
                final animValue = _toggleAnimation.value;
                final alignment = Alignment(-1.0 + (animValue * 2.0), 0.0);

                final expenseColor = Color.lerp(
                  AppColors.accentGreen,
                  AppColors.textSecondary,
                  animValue,
                )!;
                final incomeColor = Color.lerp(
                  AppColors.textSecondary,
                  AppColors.accentGreen,
                  animValue,
                )!;

                return Stack(
                  children: [
                    // Smoothly sliding white background pill
                    Align(
                      alignment: alignment,
                      child: Container(
                        width: 74,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(21),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 5,
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Labels layer
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!widget.isExpenseView) {
                                widget.onViewToggle(true);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Text(
                                'Expense',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: animValue < 0.5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: expenseColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (widget.isExpenseView) {
                                widget.onViewToggle(false);
                              }
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Text(
                                'Income',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: animValue >= 0.5
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: incomeColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(0.0),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isExpenseView
                  ? Icons.shopping_bag_outlined
                  : Icons.account_balance_wallet_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${widget.isExpenseView ? 'expenses' : 'income'} recorded',
            style: AppFonts.titleMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'for ${_getMonthName(widget.selectedMonth.month)} ${widget.selectedMonth.year}',
            style: AppFonts.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  List<CustomDonutSegment> _buildDonutSegments(
    Map<String, double> categoryData,
    double totalAmount,
  ) {
    if (totalAmount <= 0) return [];

    final List<CustomDonutSegment> segments = [];

    // Sort categories from largest to smallest for a pleasant aesthetic
    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final count = sortedEntries.length;
    final List<Color> assignedColors = [];

    for (int i = 0; i < count; i++) {
      // Pick a color from palette that is distinct from the previous segment
      // and from the first segment (if it's the last one)
      Color chosenColor = _modernDonutColors[i % _modernDonutColors.length];

      // Ensure no adjacent duplicate / collision
      if (assignedColors.isNotEmpty && chosenColor == assignedColors.last) {
        for (final candidate in _modernDonutColors) {
          if (candidate != assignedColors.last &&
              (i != count - 1 || candidate != assignedColors.first)) {
            chosenColor = candidate;
            break;
          }
        }
      }

      // Also ensure loop-around adjacency (last segment does not match first segment)
      if (i == count - 1 && count > 1 && chosenColor == assignedColors.first) {
        for (final candidate in _modernDonutColors) {
          if (candidate != assignedColors.first &&
              candidate != assignedColors.last) {
            chosenColor = candidate;
            break;
          }
        }
      }

      assignedColors.add(chosenColor);
    }

    for (int i = 0; i < count; i++) {
      final entry = sortedEntries[i];
      final percentage = (entry.value / totalAmount) * 100;
      final sweepAngle = (entry.value / totalAmount) * 2 * math.pi;

      segments.add(
        CustomDonutSegment(
          label: entry.key,
          value: entry.value,
          percentage: percentage,
          color: assignedColors[i],
          sweepAngle: sweepAngle,
        ),
      );
    }

    return segments;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

class CategoryData {
  final double value;
  final Color color;
  final String category;
  final double percentage;

  CategoryData({
    required this.value,
    required this.color,
    required this.category,
    required this.percentage,
  });
}
