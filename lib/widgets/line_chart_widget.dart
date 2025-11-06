import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models.dart';
import '../services/chart_data_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../common/currency_formatter.dart';

class LineChartWidget extends StatefulWidget {
  final List<TransactionItem> transactions;
  final DateTime startDate;
  final DateTime endDate;
  final String currencySymbol;

  const LineChartWidget({
    super.key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
    required this.currencySymbol,
  });

  @override
  State<LineChartWidget> createState() => _LineChartWidgetState();
}

class _LineChartWidgetState extends State<LineChartWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  TrendPeriod _selectedPeriod = TrendPeriod.daily;
  TransactionType _selectedType = TransactionType.expense;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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
    final trendData = ChartDataService.getTrendData(
      widget.transactions,
      widget.startDate,
      widget.endDate,
      _selectedPeriod,
      _selectedType,
    );

    if (trendData.isEmpty) {
      return _buildEmptyState();
    }

    final maxAmount = trendData.fold<double>(
      0,
      (max, data) => data.amount > max ? data.amount : max,
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
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildControls(),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((touchedSpot) {
                            final index = touchedSpot.x.toInt();
                            if (index >= 0 && index < trendData.length) {
                              final data = trendData[index];
                              return LineTooltipItem(
                                '${_formatDate(data.date)}\n'
                                '${CurrencyFormatter.format(amount: data.amount, symbol: widget.currencySymbol, decimalDigits: 0, spaceBetween: false)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }
                            return null;
                          }).where((item) => item != null).cast<LineTooltipItem>().toList();
                        },
                      ),
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
                            if (value.toInt() >= trendData.length) return const Text('');
                            return Text(
                              _formatDate(trendData[value.toInt()].date),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                          },
                          reservedSize: 30,
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: trendData.asMap().entries.map((entry) {
                          return FlSpot(
                            entry.key.toDouble(),
                            entry.value.amount * _animation.value,
                          );
                        }).toList(),
                        isCurved: true,
                        color: _selectedType == TransactionType.income
                            ? Colors.green[400]!
                            : Colors.red[400]!,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: _selectedType == TransactionType.income
                                  ? Colors.green[400]!
                                  : Colors.red[400]!,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: _selectedType == TransactionType.income
                                ? [
                                    Colors.green[400]!.withOpacity(0.3),
                                    Colors.green[400]!.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.red[400]!.withOpacity(0.3),
                                    Colors.red[400]!.withOpacity(0.1),
                                  ],
                          ),
                        ),
                      ),
                    ],
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trend Analysis',
          style: AppFonts.titleLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          '${_getDateRangeText()}',
          style: AppFonts.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        Expanded(
          child: _buildPeriodSelector(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTypeSelector(),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Period',
          style: AppFonts.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButton<TrendPeriod>(
          value: _selectedPeriod,
          isExpanded: true,
          underline: Container(),
          dropdownColor: AppColors.cardBackground,
          items: TrendPeriod.values.map((period) {
            return DropdownMenuItem(
              value: period,
              child: Text(
                _getPeriodLabel(period),
                style: AppFonts.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedPeriod = value;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: AppFonts.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButton<TransactionType>(
          value: _selectedType,
          isExpanded: true,
          underline: Container(),
          items: TransactionType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: type == TransactionType.income
                          ? AppColors.accentGreen
                          : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type == TransactionType.income ? 'Income' : 'Expense',
                    style: AppFonts.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedType = value;
              });
            }
          },
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
              Icons.trending_up_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No trend data available',
              style: AppFonts.titleLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'for the selected period',
              style: AppFonts.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(TrendPeriod period) {
    switch (period) {
      case TrendPeriod.daily:
        return 'Daily';
      case TrendPeriod.weekly:
        return 'Weekly';
      case TrendPeriod.monthly:
        return 'Monthly';
    }
  }

  String _getDateRangeText() {
    final startStr = '${widget.startDate.day}/${widget.startDate.month}/${widget.startDate.year}';
    final endStr = '${widget.endDate.day}/${widget.endDate.month}/${widget.endDate.year}';
    return '$startStr - $endStr';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }
}
