import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/chart_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../common/currency_formatter.dart';

class MonthlyComparisonChartWidget extends StatefulWidget {
  final List<TransactionItem> transactions;
  final String currencySymbol;
  final int numberOfMonths;

  const MonthlyComparisonChartWidget({
    super.key,
    required this.transactions,
    required this.currencySymbol,
    this.numberOfMonths = 6,
  });

  @override
  State<MonthlyComparisonChartWidget> createState() => _MonthlyComparisonChartWidgetState();
}

class _MonthlyComparisonChartWidgetState extends State<MonthlyComparisonChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _showIncome = true;
  bool _showExpense = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
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
    final comparisonData = ChartDataService.getMonthlyComparison(
      widget.transactions,
      widget.numberOfMonths,
    );

    if (comparisonData.every((data) => data.income == 0 && data.expense == 0)) {
      return _buildEmptyState();
    }

    final maxAmount = comparisonData.fold<double>(
      0,
      (max, data) => [
        if (_showIncome) data.income,
        if (_showExpense) data.expense,
        max
      ].reduce((a, b) => a > b ? a : b),
    );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildToggleButtons(),
          const SizedBox(height: 20),
          Container(
            height: 320,
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: comparisonData.length * 70.0,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceBetween,
                        maxY: maxAmount * 1.15,
                        minY: 0,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchCallback: (FlTouchEvent event, barTouchResponse) {
                            if (event is FlTapUpEvent && barTouchResponse != null) {
                              final group = barTouchResponse.spot?.touchedBarGroup;
                              if (group != null) {
                                final index = group.x.toInt();
                                if (index >= 0 && index < comparisonData.length) {
                                  _showMonthDetails(comparisonData[index]);
                                }
                              }
                            }
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < comparisonData.length) {
                                  final data = comparisonData[index];
                                  final isCurrentMonth = _isCurrentMonth(data.year, data.month);
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getMonthName(data.month),
                                        style: TextStyle(
                                          color: isCurrentMonth ? AppColors.accentGreen : Colors.black54,
                                          fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 9,
                                        ),
                                      ),
                                      if (isCurrentMonth)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: AppColors.accentGreen,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 35,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${CurrencyFormatter.format(amount: value / 1000, symbol: widget.currencySymbol, decimalDigits: 0, spaceBetween: false)}K',
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        barGroups: comparisonData.asMap().entries.map((entry) {
                          final index = entry.key;
                          final data = entry.value;
                          final isCurrentMonth = _isCurrentMonth(data.year, data.month);
                          
                          final barRods = <BarChartRodData>[];
                          
                          if (_showIncome) {
                            barRods.add(
                              BarChartRodData(
                                toY: data.income * _animation.value,
                                color: isCurrentMonth 
                                    ? AppColors.accentGreen 
                                    : AppColors.accentGreen.withOpacity(0.6),
                                width: 20,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            );
                          }
                          
                          if (_showExpense) {
                            barRods.add(
                              BarChartRodData(
                                toY: data.expense * _animation.value,
                                color: isCurrentMonth 
                                    ? AppColors.error 
                                    : AppColors.error.withOpacity(0.6),
                                width: 20,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            );
                          }
                          
                          return BarChartGroupData(
                            x: index,
                            barRods: barRods,
                            barsSpace: 8,
                          );
                        }).toList(),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maxAmount > 0 ? maxAmount / 5 : 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Comparison',
          style: AppFonts.titleLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'Last ${widget.numberOfMonths} months',
          style: AppFonts.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showIncome = !_showIncome;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _showIncome 
                    ? AppColors.accentGreen.withOpacity(0.2)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showIncome 
                      ? AppColors.accentGreen 
                      : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 16,
                    color: _showIncome 
                        ? AppColors.accentGreen 
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Income',
                    style: AppFonts.bodySmall.copyWith(
                      color: _showIncome 
                          ? AppColors.accentGreen 
                          : Colors.grey[600],
                      fontWeight: _showIncome ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showExpense = !_showExpense;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _showExpense 
                    ? AppColors.error.withOpacity(0.2)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showExpense 
                      ? AppColors.error 
                      : Colors.grey[400]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_down,
                    size: 16,
                    color: _showExpense 
                        ? AppColors.error 
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Expense',
                    style: AppFonts.bodySmall.copyWith(
                      color: _showExpense 
                          ? AppColors.error 
                          : Colors.grey[600],
                      fontWeight: _showExpense ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(AppColors.accentGreen, 'Income'),
        const SizedBox(width: 24),
        _buildLegendItem(AppColors.error, 'Expense'),
        const SizedBox(width: 24),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Current Month',
              style: AppFonts.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppFonts.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No transaction data',
              style: AppFonts.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for the last ${widget.numberOfMonths} months',
              style: AppFonts.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthDetails(MonthlyComparisonData data) {
    final balance = data.balance;
    final balanceColor = balance >= 0 ? Colors.green : Colors.red;
    final isCurrentMonth = _isCurrentMonth(data.year, data.month);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month,
                  color: isCurrentMonth ? AppColors.accentGreen : Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_getMonthName(data.month)} ${data.year}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            _buildDetailCard(
              icon: Icons.trending_up,
              iconColor: Colors.green[600]!,
              title: 'Income',
              amount: data.income,
              backgroundColor: Colors.green[50]!,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              icon: Icons.trending_down,
              iconColor: Colors.red[600]!,
              title: 'Expense',
              amount: data.expense,
              backgroundColor: Colors.red[50]!,
            ),
            const SizedBox(height: 16),
            _buildDetailCard(
              icon: balance >= 0 ? Icons.account_balance_wallet : Icons.warning,
              iconColor: balanceColor,
              title: 'Balance',
              amount: balance,
              backgroundColor: balanceColor.withOpacity(0.1),
              isBalance: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double amount,
    required Color backgroundColor,
    bool isBalance = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(
                    amount: amount,
                    symbol: widget.currencySymbol,
                    decimalDigits: 0,
                    spaceBetween: false,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isBalance ? iconColor : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          if (isBalance)
            Icon(
              amount >= 0 ? Icons.check_circle : Icons.error,
              color: iconColor,
              size: 24,
            ),
        ],
      ),
    );
  }

  bool _isCurrentMonth(int year, int month) {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
}

