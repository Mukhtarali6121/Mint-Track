import 'package:flutter/material.dart';
import '../models.dart';

class ChartDataService {
  static const List<Color> chartColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF5722), // Deep Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF8BC34A), // Light Green
  ];

  /// Get expense breakdown by category for pie chart
  static Map<String, double> getExpenseBreakdownByCategory(
    List<TransactionItem> transactions,
    DateTime selectedMonth,
  ) {
    final Map<String, double> categoryTotals = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense &&
          transaction.date.year == selectedMonth.year &&
          transaction.date.month == selectedMonth.month) {
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    return categoryTotals;
  }

  /// Get income breakdown by category for pie chart
  static Map<String, double> getIncomeBreakdownByCategory(
    List<TransactionItem> transactions,
    DateTime selectedMonth,
  ) {
    final Map<String, double> categoryTotals = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income &&
          transaction.date.year == selectedMonth.year &&
          transaction.date.month == selectedMonth.month) {
        categoryTotals[transaction.category] =
            (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    return categoryTotals;
  }

  /// Get monthly income vs expense data for bar chart
  static List<MonthlyData> getMonthlyIncomeVsExpense(
    List<TransactionItem> transactions,
    int selectedYear,
  ) {
    final List<MonthlyData> monthlyData = List.generate(12, (index) => MonthlyData(month: index + 1));

    for (final transaction in transactions) {
      if (transaction.date.year == selectedYear) {
        final monthIndex = transaction.date.month - 1;
        if (transaction.type == TransactionType.income) {
          monthlyData[monthIndex].income += transaction.amount;
        } else {
          monthlyData[monthIndex].expense += transaction.amount;
        }
      }
    }
    return monthlyData;
  }

  /// Get trend data for line chart
  static List<TrendData> getTrendData(
    List<TransactionItem> transactions,
    DateTime startDate,
    DateTime endDate,
    TrendPeriod period,
    TransactionType type,
  ) {
    final Map<DateTime, double> dailyTotals = {};
    for (final transaction in transactions) {
      if (transaction.type == type &&
          transaction.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
          transaction.date.isBefore(endDate.add(const Duration(days: 1)))) {
        final dateKey = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + transaction.amount;
      }
    }

    final List<TrendData> trendData = [];
    DateTime currentDate = startDate;
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      double totalAmount = 0;
      if (period == TrendPeriod.daily) {
        totalAmount = dailyTotals[currentDate] ?? 0;
        trendData.add(TrendData(date: currentDate, amount: totalAmount));
        currentDate = currentDate.add(const Duration(days: 1));
      } else if (period == TrendPeriod.weekly) {
        DateTime endOfWeek = currentDate.add(const Duration(days: 6));
        for (final entry in dailyTotals.entries) {
          if ((entry.key.isAfter(currentDate.subtract(const Duration(days: 1))) && entry.key.isBefore(endOfWeek.add(const Duration(days: 1)))) ||
              entry.key.isAtSameMomentAs(currentDate) || entry.key.isAtSameMomentAs(endOfWeek)) {
            totalAmount += entry.value;
          }
        }
        trendData.add(TrendData(date: currentDate, amount: totalAmount));
        currentDate = endOfWeek.add(const Duration(days: 1));
      } else if (period == TrendPeriod.monthly) {
        DateTime endOfMonth = DateTime(currentDate.year, currentDate.month + 1, 0);
        for (final entry in dailyTotals.entries) {
          if ((entry.key.isAfter(currentDate.subtract(const Duration(days: 1))) && entry.key.isBefore(endOfMonth.add(const Duration(days: 1)))) ||
              entry.key.isAtSameMomentAs(currentDate) || entry.key.isAtSameMomentAs(endOfMonth)) {
            totalAmount += entry.value;
          }
        }
        trendData.add(TrendData(date: currentDate, amount: totalAmount));
        currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
      }
    }
    return trendData;
  }

  /// Get monthly comparison data (current month vs past months)
  /// Returns data for the last N months including current month
  static List<MonthlyComparisonData> getMonthlyComparison(
    List<TransactionItem> transactions,
    int numberOfMonths,
  ) {
    final now = DateTime.now();
    final List<MonthlyComparisonData> comparisonData = [];

    // Generate data for the last N months (including current month)
    for (int i = numberOfMonths - 1; i >= 0; i--) {
      // Calculate the month date properly handling year rollover
      final targetMonth = now.month - i;
      int year = now.year;
      int month = targetMonth;
      
      // Handle negative months (previous year)
      if (targetMonth <= 0) {
        year = now.year - 1;
        month = 12 + targetMonth;
      }
      
      // Handle months > 12 (shouldn't happen with this logic, but just in case)
      if (month > 12) {
        year += 1;
        month -= 12;
      }

      double income = 0;
      double expense = 0;

      for (final transaction in transactions) {
        if (transaction.date.year == year && transaction.date.month == month) {
          if (transaction.type == TransactionType.income) {
            income += transaction.amount;
          } else {
            expense += transaction.amount;
          }
        }
      }

      comparisonData.add(MonthlyComparisonData(
        year: year,
        month: month,
        income: income,
        expense: expense,
      ));
    }

    return comparisonData;
  }
}

class MonthlyData {
  final int month;
  double income;
  double expense;

  MonthlyData({required this.month, this.income = 0, this.expense = 0});
}

class TrendData {
  final DateTime date;
  final double amount;

  TrendData({required this.date, required this.amount});
}

class MonthlyComparisonData {
  final int year;
  final int month;
  final double income;
  final double expense;

  MonthlyComparisonData({
    required this.year,
    required this.month,
    this.income = 0,
    this.expense = 0,
  });

  double get balance => income - expense;
}