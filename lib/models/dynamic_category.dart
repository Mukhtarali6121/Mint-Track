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
      'insurance': 'assets/images/new/ic_insurance.svg',
      'investment': 'assets/images/new/ic_investment.svg',
      'investments': 'assets/images/new/ic_investment.svg',
      'fuel and transportation': 'assets/images/new/ic_fuel.svg',
      'fuel & transportation': 'assets/images/new/ic_fuel.svg',
      'fuel': 'assets/images/new/ic_fuel.svg',
      'transportation': 'assets/images/new/ic_fuel.svg',
      'credit card bill': 'assets/images/new/ic_credit_card.svg',
      'credit card': 'assets/images/new/ic_credit_card.svg',
      'credit_card': 'assets/images/new/ic_credit_card.svg',
      'creditcard': 'assets/images/new/ic_credit_card.svg',
      'cash withdrawal': 'assets/images/new/ic_family_transfer.svg',
      'cash_withdrawal': 'assets/images/new/ic_family_transfer.svg',
      'family transfer': 'assets/images/new/ic_family_transfer.svg',
      'family_transfer': 'assets/images/new/ic_family_transfer.svg',
      'gifts': 'assets/images/new/ic_gift.svg',
      'gift': 'assets/images/new/ic_gift.svg',
      'personal care': 'assets/images/new/ic_personal_care.svg',
      'personal_care': 'assets/images/new/ic_personal_care.svg',
      'personalcare': 'assets/images/new/ic_personal_care.svg',
      'beauty': 'assets/images/new/ic_personal_care.svg',
      'repair': 'assets/images/new/ic_repairs.svg',
      'repairs': 'assets/images/new/ic_repairs.svg',
      'maintenance': 'assets/images/new/ic_repairs.svg',
      'maintenance & repairs': 'assets/images/new/ic_repairs.svg',
      'self care': 'assets/images/new/ic_mental_wellness.svg',
      'self_care': 'assets/images/new/ic_mental_wellness.svg',
      'mental wellness': 'assets/images/new/ic_mental_wellness.svg',
      'mental_wellness': 'assets/images/new/ic_mental_wellness.svg',
      'wellness': 'assets/images/new/ic_mental_wellness.svg',
      'birthdays': 'assets/images/new/ic_birthday.svg',
      'birthday': 'assets/images/new/ic_birthday.svg',
      'yoga & meditation': 'assets/images/new/ic_yoga.svg',
      'yoga and meditation': 'assets/images/new/ic_yoga.svg',
      'yoga': 'assets/images/new/ic_yoga.svg',
      'fitness': 'assets/images/new/ic_gym.svg',
      'gym': 'assets/images/new/ic_gym.svg',
      'renovation': 'assets/images/new/ic_renovation.svg',
      'renovations': 'assets/images/new/ic_renovation.svg',
      'home renovation': 'assets/images/new/ic_renovation.svg',
      'bills & utilities': 'assets/images/new/ic_bills_utilities.svg',
      'bills and utilities': 'assets/images/new/ic_bills_utilities.svg',
      'bills': 'assets/images/new/ic_bills_utilities.svg',
      'utilities': 'assets/images/new/ic_bills_utilities.svg',
      'groceries': 'assets/images/new/ic_groceries.svg',
      'grocery': 'assets/images/new/ic_groceries.svg',
      'food & dining': 'assets/images/new/ic_food.svg',
      'food and dining': 'assets/images/new/ic_food.svg',
      'food': 'assets/images/new/ic_food.svg',
      'dining': 'assets/images/new/ic_food.svg',
      'entertainment': 'assets/images/new/ic_entertainment.svg',
      'entertainments': 'assets/images/new/ic_entertainment.svg',
      'movie': 'assets/images/new/ic_entertainment.svg',
      'movies': 'assets/images/new/ic_entertainment.svg',
      'hospital': 'assets/images/new/ic_hospital.svg',
      'hospitals': 'assets/images/new/ic_hospital.svg',
      'medical': 'assets/images/new/ic_hospital.svg',
      'health': 'assets/images/new/ic_hospital.svg',
      'healthcare': 'assets/images/new/ic_hospital.svg',
      'charges': 'assets/images/new/ic_charges.svg',
      'charge': 'assets/images/new/ic_charges.svg',
      'fee': 'assets/images/new/ic_charges.svg',
      'fees': 'assets/images/new/ic_charges.svg',
      'tax': 'assets/images/new/ic_tax.svg',
      'taxes': 'assets/images/new/ic_tax.svg',
      'education': 'assets/images/new/ic_education.svg',
      'studies': 'assets/images/new/ic_education.svg',
      'study': 'assets/images/new/ic_education.svg',
      'college': 'assets/images/new/ic_education.svg',
      'school': 'assets/images/new/ic_education.svg',
      'tuition': 'assets/images/new/ic_education.svg',
      'loan': 'assets/images/new/ic_loan.svg',
      'loans': 'assets/images/new/ic_loan.svg',
      'emi': 'assets/images/new/ic_loan.svg',
      'debt': 'assets/images/new/ic_loan.svg',
      'shopping': 'assets/images/new/ic_shopping.svg',
      'clothes': 'assets/images/new/ic_shopping.svg',
      'clothing': 'assets/images/new/ic_shopping.svg',
      'store': 'assets/images/new/ic_shopping.svg',
      'subscription': 'assets/images/new/ic_subscription.svg',
      'subscriptions': 'assets/images/new/ic_subscription.svg',
      'membership': 'assets/images/new/ic_subscription.svg',
      'memberships': 'assets/images/new/ic_subscription.svg',
      'travel': 'assets/images/new/ic_travel.svg',
      'travels': 'assets/images/new/ic_travel.svg',
      'vacation': 'assets/images/new/ic_travel.svg',
      'flight': 'assets/images/new/ic_travel.svg',
      'trip': 'assets/images/new/ic_travel.svg',
      'holiday': 'assets/images/new/ic_travel.svg',
      'other': 'assets/images/new/ic_others.svg',
      'others': 'assets/images/new/ic_others.svg',
    };

    return iconMap[name.toLowerCase().trim()] ??
        iconMap[iconName.toLowerCase().trim()] ??
        'assets/images/new/ic_others.svg';
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
