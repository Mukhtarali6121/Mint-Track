import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models.dart';
import '../../transaction_provider.dart';
import '../../account_provider.dart';
import '../../widgets/pie_chart_widget.dart';
import '../../widgets/bar_chart_widget.dart';
import '../../widgets/line_chart_widget.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_fonts.dart';
import '../../common/currency_provider.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  int _selectedYear = DateTime.now().year;
  bool _isExpenseView = true;
  String? _selectedAccountId; // null means "All Accounts"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Get unique years from transactions
  List<int> _getAvailableYears(List<TransactionItem> transactions) {
    final years = transactions.map((t) => t.date.year).toSet().toList();
    years.sort();
    return years.isEmpty ? [DateTime.now().year] : years;
  }

  /// Get unique months from transactions for a given year
  List<int> _getAvailableMonths(List<TransactionItem> transactions, int year) {
    final months = transactions
        .where((t) => t.date.year == year)
        .map((t) => t.date.month)
        .toSet()
        .toList();
    months.sort();
    return months.isEmpty ? [DateTime.now().month] : months;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Analytics',
          style: AppFonts.appBarTitle.copyWith(
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: Icon(
        //       Icons.calendar_month_outlined,
        //       color: AppColors.textPrimary,
        //     ),
        //     onPressed: _showDatePicker,
        //   ),
        // ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F9F8),
              Color(0xFFE8F5E9),
              Color(0xFFF1F8E9),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Consumer3<TransactionProvider, CurrencyProvider, AccountProvider>(
            builder: (context, transactionProvider, currencyProvider, accountProvider, child) {
              if (!transactionProvider.isInitialized) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentGreen,
                  ),
                );
              }

              // Filter transactions by selected account
              var filteredTransactions = transactionProvider.items;
              if (_selectedAccountId != null) {
                filteredTransactions = transactionProvider.getTransactionsByAccount(_selectedAccountId!);
              }

              final availableYears = _getAvailableYears(filteredTransactions);
              
              // Ensure selected year is valid
              if (!availableYears.contains(_selectedYear)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedYear = availableYears.isEmpty ? DateTime.now().year : availableYears.first;
                    _selectedMonth = DateTime(_selectedYear, _selectedMonth.month);
                  });
                });
              }
              
              final availableMonths = _getAvailableMonths(filteredTransactions, _selectedYear);
              
              // Ensure selected month is valid
              if (!availableMonths.contains(_selectedMonth.month)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedMonth = DateTime(_selectedYear, availableMonths.isEmpty ? DateTime.now().month : availableMonths.first);
                  });
                });
              }
              
              return Column(
                children: [
                  // Account Selector
                  _buildAccountSelector(accountProvider),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPieChartTab(filteredTransactions, currencyProvider.currencySymbol, availableMonths),
                        _buildBarChartTab(filteredTransactions, currencyProvider.currencySymbol, availableYears),
                        _buildLineChartTab(filteredTransactions, currencyProvider.currencySymbol, availableYears, availableMonths),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.accentGreen,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentGreen,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppFonts.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppFonts.labelMedium,
          tabs: const [
            Tab(
              icon: Icon(Icons.pie_chart),
              text: 'Breakdown',
            ),
            Tab(
              icon: Icon(Icons.bar_chart_outlined),
              text: 'Monthly',
            ),
            Tab(
              icon: Icon(Icons.trending_up_outlined),
              text: 'Trend',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartTab(List<TransactionItem> transactions, String currencySymbol, List<int> availableMonths) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PieChartWidget(
            transactions: transactions,
            selectedMonth: _selectedMonth,
            isExpenseView: _isExpenseView,
            onViewToggle: (isExpense) {
              setState(() {
                _isExpenseView = isExpense;
              });
            },
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: 20),
          _buildMonthSelector(availableMonths, transactions.isNotEmpty ? _getAvailableYears(transactions) : null),
        ],
      ),
    );
  }

  Widget _buildBarChartTab(List<TransactionItem> transactions, String currencySymbol, List<int> availableYears) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BarChartWidget(
            transactions: transactions,
            selectedYear: _selectedYear,
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: 20),
          _buildYearSelector(availableYears),
        ],
      ),
    );
  }

  Widget _buildLineChartTab(List<TransactionItem> transactions, String currencySymbol, List<int> availableYears, List<int> availableMonths) {
    final startDate = DateTime(_selectedYear, _selectedMonth.month, 1);
    final endDate = DateTime(_selectedYear, _selectedMonth.month + 1, 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LineChartWidget(
            transactions: transactions,
            startDate: startDate,
            endDate: endDate,
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: 20),
          _buildDateRangeSelector(availableYears, availableMonths),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(List<int> availableMonths, [List<int>? availableYears]) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Select Month',
            style: AppFonts.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth.month,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    labelStyle: AppFonts.inputLabel.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.backgroundScaffold,
                  ),
                  dropdownColor: AppColors.cardBackground,
                  items: availableMonths.map((month) {
                    return DropdownMenuItem(
                      value: month,
                      child: Text(
                        _getMonthName(month),
                        style: AppFonts.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, value);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth.year,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    labelStyle: AppFonts.inputLabel.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.backgroundScaffold,
                  ),
                  dropdownColor: AppColors.cardBackground,
                  items: (availableYears ?? [DateTime.now().year]).map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: AppFonts.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = DateTime(value, _selectedMonth.month);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector(List<int> availableYears) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Select Year',
            style: AppFonts.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: InputDecoration(
              labelText: 'Year',
              labelStyle: AppFonts.inputLabel.copyWith(
                color: AppColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accentGreen),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
                    fillColor: AppColors.backgroundScaffold,
            ),
            dropdownColor: Colors.white,
            items: availableYears.map((year) {
              return DropdownMenuItem(
                value: year,
                child: Text(
                  year.toString(),
                  style: AppFonts.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedYear = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector(List<int> availableYears, List<int> availableMonths) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            'Select Month & Year',
            style: AppFonts.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth.month,
                  decoration: InputDecoration(
                    labelText: 'Month',
                    labelStyle: AppFonts.inputLabel.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.backgroundScaffold,
                  ),
                  dropdownColor: AppColors.cardBackground,
                  items: availableMonths.map((month) {
                    return DropdownMenuItem(
                      value: month,
                      child: Text(
                        _getMonthName(month),
                        style: AppFonts.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMonth = DateTime(_selectedMonth.year, value);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedMonth.year,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    labelStyle: AppFonts.inputLabel.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.accentGreen),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.backgroundScaffold,
                  ),
                  dropdownColor: AppColors.cardBackground,
                  items: availableYears.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: AppFonts.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedYear = value;
                        _selectedMonth = DateTime(value, _selectedMonth.month);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accentGreen,
              onPrimary: Colors.white,
              surface: AppColors.cardBackground,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    ).then((selectedDate) {
      if (selectedDate != null) {
        setState(() {
          _selectedMonth = selectedDate;
          _selectedYear = selectedDate.year;
        });
      }
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildAccountSelector(AccountProvider accountProvider) {
    final accounts = accountProvider.accounts;
    
    if (accounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet,
            color: AppColors.accentGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedAccountId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              hint: const Text(
                'All Accounts',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All Accounts',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...accounts.map((account) {
                  return DropdownMenuItem<String>(
                    value: account.id,
                    child: Text(
                      account.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedAccountId = newValue;
                });
              },
              style: AppFonts.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
