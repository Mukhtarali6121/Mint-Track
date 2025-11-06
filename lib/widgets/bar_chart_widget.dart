import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/chart_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../common/currency_formatter.dart';

class BarChartWidget extends StatefulWidget {
  final List<TransactionItem> transactions;
  final int selectedYear;
  final String currencySymbol;

  const BarChartWidget({
    super.key,
    required this.transactions,
    required this.selectedYear,
    required this.currencySymbol,
  });

  @override
  State<BarChartWidget> createState() => _BarChartWidgetState();
}

class _BarChartWidgetState extends State<BarChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

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
    final monthlyData = ChartDataService.getMonthlyIncomeVsExpense(
      widget.transactions,
      widget.selectedYear,
    );

    if (monthlyData.every((data) => data.income == 0 && data.expense == 0)) {
      return _buildEmptyState();
    }

    final maxAmount = monthlyData.fold<double>(
      0,
      (max, data) => [data.income, data.expense, max].reduce((a, b) => a > b ? a : b),
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
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                Icons.swipe_left,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Swipe to view all months',
                style: AppFonts.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 320, // Reduced height since tooltips are now below
            padding: const EdgeInsets.symmetric(vertical: 20.0), // Add vertical padding for tooltips
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: monthlyData.length * 70.0, // Increased width for better spacing
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    maxY: maxAmount * 1.1, // Reduced margin since tooltips are below
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        if (event is FlTapUpEvent && barTouchResponse != null) {
                          final group = barTouchResponse.spot?.touchedBarGroup;
                          if (group != null) {
                            final index = group.x.toInt();
                            if (index >= 0 && index < monthlyData.length) {
                              _showMonthDetails(monthlyData[index]);
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
                            if (index >= 0 && index < monthlyData.length) {
                              return Text(
                                _getMonthName(monthlyData[index].month),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 25,
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
                    barGroups: monthlyData.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: data.income * _animation.value,
                            color: AppColors.accentGreen,
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          BarChartRodData(
                            toY: data.expense * _animation.value,
                            color: AppColors.error,
                            width: 20,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                        barsSpace: 8,
                      );
                    }).toList(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxAmount / 5,
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
          'Monthly Income vs Expense',
          style: AppFonts.titleLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${widget.selectedYear}',
          style: AppFonts.bodyMedium.copyWith(
            color: AppColors.textSecondary,
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
              'for ${widget.selectedYear}',
              style: AppFonts.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(Colors.green[400]!, 'Income'),
        const SizedBox(width: 24),
        _buildLegendItem(Colors.red[400]!, 'Expense'),
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showMonthDetails(MonthlyData data) {
    final balance = data.income - data.expense;
    final balanceColor = balance >= 0 ? Colors.green : Colors.red;
    
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
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Month header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month,
                  color: Colors.blue[600],
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  _getMonthName(data.month),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Income card
            _buildDetailCard(
              icon: Icons.trending_up,
              iconColor: Colors.green[600]!,
              title: 'Income',
              amount: data.income,
              backgroundColor: Colors.green[50]!,
            ),
            const SizedBox(height: 16),
            
            // Expense card
            _buildDetailCard(
              icon: Icons.trending_down,
              iconColor: Colors.red[600]!,
              title: 'Expense',
              amount: data.expense,
              backgroundColor: Colors.red[50]!,
            ),
            const SizedBox(height: 16),
            
            // Balance card
            _buildDetailCard(
              icon: balance >= 0 ? Icons.account_balance_wallet : Icons.warning,
              iconColor: balanceColor,
              title: 'Balance',
              amount: balance,
              backgroundColor: balanceColor.withOpacity(0.1),
              isBalance: true,
            ),
            const SizedBox(height: 24),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
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

  String _getMonthName(int month) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return monthNames[month - 1];
  }
}
