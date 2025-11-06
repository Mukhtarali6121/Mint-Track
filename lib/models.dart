import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum TransactionType { income, expense }

enum PeriodFilter { day, week, month, year, custom }

enum TrendPeriod { daily, weekly, monthly }

enum TransactionCategory {
  // Expense categories
  foodDining,
  shopping,
  travelling,
  entertainment,
  medical,
  personalCare,
  education,
  billsUtilities,
  investments,
  rent,
  taxes,
  insurance,
  giftsDonation,
  others,
  health,

  // Income categories
  salary,
  soldItems,
  coupons,
  pettyCash,
  bonus,
}

extension TransactionCategoryExtension on TransactionCategory {
  String get displayName {
    switch (this) {
      case TransactionCategory.foodDining:
        return 'Food & Dining';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.travelling:
        return 'Travelling';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.medical:
        return 'Medical';
      case TransactionCategory.personalCare:
        return 'Personal Care';
      case TransactionCategory.education:
        return 'Education';
      case TransactionCategory.billsUtilities:
        return 'Bills & Utilities';
      case TransactionCategory.investments:
        return 'Investments';
      case TransactionCategory.rent:
        return 'Rent';
      case TransactionCategory.taxes:
        return 'Taxes';
      case TransactionCategory.insurance:
        return 'Insurance';
      case TransactionCategory.giftsDonation:
        return 'Gifts & Donation';
      case TransactionCategory.others:
        return 'Others';
      case TransactionCategory.health:
        return 'Health';
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.soldItems:
        return 'Sold Items';
      case TransactionCategory.coupons:
        return 'Coupons';
      case TransactionCategory.pettyCash:
        return 'Petty Cash';
      case TransactionCategory.bonus:
        return 'Bonus';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionCategory.foodDining:
        return Icons.restaurant;
      case TransactionCategory.shopping:
        return Icons.shopping_bag;
      case TransactionCategory.travelling:
        return Icons.flight;
      case TransactionCategory.entertainment:
        return Icons.movie;
      case TransactionCategory.medical:
        return Icons.local_hospital;
      case TransactionCategory.personalCare:
        return Icons.spa;
      case TransactionCategory.education:
        return Icons.school;
      case TransactionCategory.billsUtilities:
        return Icons.receipt;
      case TransactionCategory.investments:
        return Icons.trending_up;
      case TransactionCategory.rent:
        return Icons.home;
      case TransactionCategory.taxes:
        return Icons.account_balance;
      case TransactionCategory.insurance:
        return Icons.security;
      case TransactionCategory.giftsDonation:
        return Icons.card_giftcard;
      case TransactionCategory.others:
        return Icons.category;
      case TransactionCategory.health:
        return Icons.healing;
      case TransactionCategory.salary:
        return Icons.work;
      case TransactionCategory.soldItems:
        return Icons.sell;
      case TransactionCategory.coupons:
        return Icons.local_offer;
      case TransactionCategory.pettyCash:
        return Icons.account_balance_wallet;
      case TransactionCategory.bonus:
        return Icons.emoji_events;
    }
  }

  Color get color {
    switch (this) {
      // Expense categories
      case TransactionCategory.foodDining:
        return Colors.orange;
      case TransactionCategory.shopping:
        return Colors.purple;
      case TransactionCategory.travelling:
        return Colors.blue;
      case TransactionCategory.entertainment:
        return Colors.pink;
      case TransactionCategory.medical:
        return Colors.red;
      case TransactionCategory.personalCare:
        return Colors.teal;
      case TransactionCategory.education:
        return Colors.indigo;
      case TransactionCategory.billsUtilities:
        return Colors.amber;
      case TransactionCategory.investments:
        return Colors.green;
      case TransactionCategory.rent:
        return Colors.brown;
      case TransactionCategory.taxes:
        return Colors.deepOrange;
      case TransactionCategory.insurance:
        return Colors.cyan;
      case TransactionCategory.giftsDonation:
        return Colors.lightGreen;
      case TransactionCategory.health:
        return Colors.redAccent;
      case TransactionCategory.others:
        return Colors.grey;
      
      // Income categories
      case TransactionCategory.salary:
        return Colors.green;
      case TransactionCategory.soldItems:
        return Colors.lightBlue;
      case TransactionCategory.coupons:
        return Colors.yellow;
      case TransactionCategory.pettyCash:
        return Colors.lime;
      case TransactionCategory.bonus:
        return Colors.amberAccent;
    }
  }

}

class TransactionCategoryHelper {
  static List<TransactionCategory> getExpenseCategories() {
    return [
      TransactionCategory.foodDining,
      TransactionCategory.shopping,
      TransactionCategory.travelling,
      TransactionCategory.entertainment,
      TransactionCategory.medical,
      TransactionCategory.personalCare,
      TransactionCategory.education,
      TransactionCategory.billsUtilities,
      TransactionCategory.investments,
      TransactionCategory.rent,
      TransactionCategory.taxes,
      TransactionCategory.insurance,
      TransactionCategory.giftsDonation,
      TransactionCategory.others,
    ];
  }

  static List<TransactionCategory> getIncomeCategories() {
    return [
      TransactionCategory.salary,
      TransactionCategory.soldItems,
      TransactionCategory.coupons,
      TransactionCategory.pettyCash,
      TransactionCategory.bonus,
      TransactionCategory.others,
    ];
  }
}
@immutable
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.note,
    this.accountId = 'cash',
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String category;
  final String? note;
  final String accountId;

  @override
  String toString() {
    return 'TransactionItem(id: $id, title: $title, amount: $amount, type: $type, date: $date, category: $category, note: $note, accountId: $accountId)';
  }

  TransactionItem copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    DateTime? date,
    String? category,
    String? note,
    String? accountId,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': describeEnum(type),
    'date': date.toIso8601String(),
    'category': category,
    'note': note,
    'accountId': accountId,
  };

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    return TransactionItem(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
            (e) => describeEnum(e) == json['type'],
        orElse: () => TransactionType.expense,
      ),
      date: DateTime.parse(json['date'] as String),
      category: json['category'] as String? ?? 'Others',
      note: json['note'] as String?,
      accountId: json['accountId'] as String? ?? 'cash',
    );
  }
}
