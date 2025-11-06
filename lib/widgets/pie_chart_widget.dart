import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/chart_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../common/currency_formatter.dart';

class PieChartWidget extends StatefulWidget {
  final List<TransactionItem> transactions;
  final DateTime selectedMonth;
  final bool isExpenseView;
  final Function(bool) onViewToggle;
  final String currencySymbol;

  const PieChartWidget({
    Key? key,
    required this.transactions,
    required this.selectedMonth,
    required this.isExpenseView,
    required this.onViewToggle,
    required this.currencySymbol,
  }) : super(key: key);

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryData = widget.isExpenseView
        ? ChartDataService.getExpenseBreakdownByCategory(
            widget.transactions, widget.selectedMonth)
        : ChartDataService.getIncomeBreakdownByCategory(
            widget.transactions, widget.selectedMonth);

    if (categoryData.isEmpty) {
      return _buildEmptyState();
    }

    final totalAmount = categoryData.values.fold(0.0, (sum, amount) => sum + amount);
    final pieChartData = _buildPieChartData(categoryData);

    // Safety check to ensure we have data
    if (pieChartData.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(totalAmount),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (event is FlTapUpEvent && 
                            pieTouchResponse != null && 
                            pieTouchResponse.touchedSection != null) {
                          final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          if (index >= 0 && index < pieChartData.length) {
                            _showCategoryDetails(index, pieChartData);
                          }
                        }
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: pieChartData.map((data) {
                      return PieChartSectionData(
                        color: data.color,
                        value: data.value * _animation.value,
                        title: '',
                        radius: 70,
                        titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(pieChartData),
        ],
      ),
    );
  }

  Widget _buildHeader(double totalAmount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isExpenseView ? 'Expense Breakdown' : 'Income Breakdown',
              style: AppFonts.titleLarge.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              CurrencyFormatter.format(
                amount: totalAmount,
                symbol: widget.currencySymbol,
                decimalDigits: 0,
                spaceBetween: false,
              ),
              style: AppFonts.displaySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        Switch(
          value: widget.isExpenseView,
          onChanged: widget.onViewToggle,
          activeColor: AppColors.accentGreen,
          inactiveThumbColor: AppColors.accentGreen,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(0.0),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isExpenseView ? Icons.shopping_cart_outlined : Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No ${widget.isExpenseView ? 'expenses' : 'income'} data',
                    style: AppFonts.titleLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'for ${_getMonthName(widget.selectedMonth.month)} ${widget.selectedMonth.year}',
                    style: AppFonts.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CategoryData> _buildPieChartData(Map<String, double> categoryData) {
    final totalAmount = categoryData.values.fold(0.0, (sum, amount) => sum + amount);
    final colors = ChartDataService.chartColors;
    final List<CategoryData> pieData = [];
    
    int colorIndex = 0;
    categoryData.forEach((category, amount) {
      pieData.add(CategoryData(
        value: amount,
        color: colors[colorIndex % colors.length],
        category: category,
        percentage: (amount / totalAmount) * 100,
      ));
      colorIndex++;
    });

    return pieData;
  }

  Widget _buildLegend(List<CategoryData> pieData) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: pieData.map((data) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: data.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              data.category,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  void _showCategoryDetails(int index, List<CategoryData> pieData) {
    // Additional safety check
    if (index < 0 || index >= pieData.length) {
      return;
    }
    
    final data = pieData[index];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: data.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${data.percentage.toStringAsFixed(1)}% of total',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.format(
                    amount: data.value,
                    symbol: widget.currencySymbol,
                    decimalDigits: 0,
                    spaceBetween: false,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
