import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

part 'category.g.dart';

@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String iconName;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  int position;

  Category({
    required this.name,
    required this.iconName,
    required this.colorValue,
    required this.position,
  });

  // Helper function to get the SVG icon path
  String getIconPath(String iconName) {
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

    // Look up the icon name (case-insensitive) in the map.
    // If not found, return the path for the default 'others' icon.
    return iconMap[iconName.toLowerCase()] ?? 'assets/images/ic_vector_other.svg';
  }
  // Get SVG icon path based on category name
  String get iconPath => getIconPath(iconName);

  Color get color => Color(colorValue);

  String get displayName => name;

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorValue': colorValue,
      'position': position,
    };
  }

  // Create from Map (Firestore format)
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      name: map['name'] ?? '',
      iconName: map['iconName'] ?? 'category',
      colorValue: map['colorValue'] ?? Colors.blue.value,
      position: map['position'] ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          iconName == other.iconName &&
          colorValue == other.colorValue &&
          position == other.position;

  @override
  int get hashCode =>
      name.hashCode ^
      iconName.hashCode ^
      colorValue.hashCode ^
      position.hashCode;

  @override
  String toString() => name;
}
