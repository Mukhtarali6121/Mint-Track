import 'package:flutter/material.dart';

class DynamicCategory {
  final String name;
  final String iconName;

  const DynamicCategory({
    required this.name,
    required this.iconName,
  });

  // Get SVG icon path based on category name
  String get iconPath {
    // Map category names to their corresponding SVG file paths
    const Map<String, String> iconMap = {
      // Expense categories
      'food': 'assets/images/ic_vector_food.svg',
      'drinks': 'assets/images/ic_vector_drink.svg',
      'transportation': 'assets/images/ic_vector_transportation.svg',
      'housing': 'assets/images/ic_vector_home.svg',
      'shopping': 'assets/images/ic_vector_shopping_bag.svg',
      'health': 'assets/images/ic_vector_health.svg',
      'fitness': 'assets/images/ic_vector_fitness.svg',
      'entertainment': 'assets/images/ic_vector_entertainment.svg',
      'games': 'assets/images/ic_vector_game.svg',
      'education': 'assets/images/ic_vector_education.svg',
      'loans': 'assets/images/ic_vector_loan.svg',
      'savings': 'assets/images/ic_vector_investment.svg',
      'investments': 'assets/images/ic_vector_investment.svg',
      'travel': 'assets/images/ic_vector_travel.svg',
      'gifts': 'assets/images/ic_vector_gifts.svg',
      'donations': 'assets/images/ic_vector_donate.svg',
      'beauty': 'assets/images/ic_vector_beauty.svg',
      'taxes': 'assets/images/ic_vector_tax.svg',
      'others': 'assets/images/ic_vector_other.svg',
      
      // Income categories
      'salary': 'assets/images/ic_vector_salary.svg',
      'business': 'assets/images/ic_vector_business.svg',
      'interest income': 'assets/images/ic_vector_interest_income.svg',
      'rental income': 'assets/images/ic_vector_rental_income.svg',
    };

    return iconMap[name.toLowerCase()] ?? 'assets/images/ic_vector_other.svg';
  }

  String get displayName => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DynamicCategory && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}
