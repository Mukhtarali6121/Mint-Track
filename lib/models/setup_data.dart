import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'category.dart';

part 'setup_data.g.dart';

@HiveType(typeId: 0)
class SetupData extends HiveObject {
  @HiveField(0)
  String currencyCode;

  @HiveField(6) // Use new, non-conflicting index
  String currencySymbol;

  @HiveField(7) // Use new, non-conflicting index
  String country;

  @HiveField(1)
  String financialGoal;

  @HiveField(2)
  List<Category> expenseCategories;

  @HiveField(3)
  List<Category> incomeCategories;

  @HiveField(4)
  DateTime timestamp;

  @HiveField(5)
  String userId;


  SetupData({
    required this.currencyCode,
    required this.currencySymbol,
    required this.country,
    required this.financialGoal,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.timestamp,
    required this.userId,
  });

  // Convert from Map (Firestore format) to SetupData
  factory SetupData.fromMap(Map<String, dynamic> map, String userId) {
    String tempCode = '';
    String tempSymbol = '';
    String tempCountry = '';

    if (map['Currency'] is Map) {
      // New format: handles the map directly
      final currencyMap = map['Currency'] as Map<String, dynamic>;
      tempCode = currencyMap['currencyCode'] ?? '';
      tempSymbol = currencyMap['currencySymbol'] ?? '';
      tempCountry = currencyMap['country'] ?? '';
    } else if (map['Currency'] is String) {
      // Old format: for backward compatibility, parse the string
      final currencyString = map['Currency'] as String; // e.g., "🇮🇳 INR (₹)"
      final parts = currencyString.split(' ');
      if (parts.length >= 2) {
        tempCode = parts[1];
      }
      final symbolMatch = RegExp(r'\((.*?)\)').firstMatch(currencyString);
      if (symbolMatch != null) {
        tempSymbol = symbolMatch.group(1) ?? '';
      }
      tempCountry = 'N/A'; // Country info is not in the old string format
    }

    // Category parsing logic remains the same
    List<Category> expenseCategories = [];
    if (map['ExpenseCategories'] != null) {
      expenseCategories = (map['ExpenseCategories'] as List)
          .map((item) => Category.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    List<Category> incomeCategories = [];
    if (map['IncomeCategories'] != null) {
      incomeCategories = (map['IncomeCategories'] as List)
          .map((item) => Category.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return SetupData(
      currencyCode: tempCode,
      currencySymbol: tempSymbol,
      country: tempCountry,
      financialGoal: map['FinancialGoal'] ?? '',
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      userId: userId,
    );
  }

  // Convert to Map (Firestore format)
  Map<String, dynamic> toMap() {
    return {
      'Currency': {
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'country': country,
      },
      'FinancialGoal': financialGoal,
      'ExpenseCategories': expenseCategories.map((cat) => cat.toMap()).toList(),
      'IncomeCategories': incomeCategories.map((cat) => cat.toMap()).toList(),
      'timestamp': FieldValue.serverTimestamp(), // Use server timestamp for consistency
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is SetupData &&
              runtimeType == other.runtimeType &&
              // MODIFIED: Compare the new currency fields
              currencyCode == other.currencyCode &&
              currencySymbol == other.currencySymbol &&
              country == other.country &&
              financialGoal == other.financialGoal &&
              _listEquals(expenseCategories, other.expenseCategories) &&
              _listEquals(incomeCategories, other.incomeCategories) &&
              timestamp == other.timestamp &&
              userId == other.userId;

  @override
  int get hashCode =>
      // MODIFIED: Combine hash codes of the new currency fields
  currencyCode.hashCode ^
  currencySymbol.hashCode ^
  country.hashCode ^
  financialGoal.hashCode ^
  expenseCategories.hashCode ^
  incomeCategories.hashCode ^
  timestamp.hashCode ^
  userId.hashCode;

  // Helper method to compare lists, required for the equality operator
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }


  // Helper method to get random light colors
  static Color _getRandomLightColor() {
    final lightColors = [
      Colors.blue.shade200,
      Colors.green.shade200,
      Colors.orange.shade200,
      Colors.purple.shade200,
      Colors.pink.shade200,
      Colors.teal.shade200,
      Colors.indigo.shade200,
      Colors.cyan.shade200,
      Colors.lime.shade200,
      Colors.amber.shade200,
    ];
    return lightColors[DateTime.now().millisecondsSinceEpoch % lightColors.length];
  }
}
