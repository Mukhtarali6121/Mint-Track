import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';

class AddEditCategoryPage extends StatefulWidget {
  final Category? existingCategory;
  final bool isExpense;
  final List<Category> currentCategories;
  final Function(Category) onSave;
  final Function(List<Category>)? onAddMultiple;

  const AddEditCategoryPage({
    super.key,
    this.existingCategory,
    required this.isExpense,
    this.currentCategories = const [],
    required this.onSave,
    this.onAddMultiple,
  });

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  final Set<String> _selectedCategories = {};

  static const List<String> expenseMasterCategories = [
    'Insurance',
    'Investment',
    'Fuel and Transportation',
    'Credit Card Bill',
    'Cash Withdrawal',
    'Gifts',
    'Personal Care',
    'Repair',
    'Self Care',
    'Birthdays',
    'Yoga & Meditation',
    'Fitness',
    'Renovation',
    'Bills & Utilities',
    'Groceries',
    'Food & Dining',
    'Entertainment',
    'Hospital',
    'Charges',
    'Tax',
    'Education',
    'Loan',
    'Shopping',
    'Subscription',
    'Travel',
  ];

  static const List<String> incomeMasterCategories = [
    'Investment',
    'Cash Withdrawal',
    'Gifts',
    'Birthdays',
  ];

  static String getIconPath(String name) {
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
        'assets/images/new/ic_others.svg';
  }

  void _saveSelectedCategories() {
    if (_selectedCategories.isEmpty) return;

    final newCategories = _selectedCategories.map((name) {
      return Category(
        name: name,
        iconName: name.toLowerCase().trim(),
        colorValue: Colors.white.value,
        position: widget.currentCategories.length,
      );
    }).toList();

    if (widget.onAddMultiple != null) {
      widget.onAddMultiple!(newCategories);
    } else {
      for (final cat in newCategories) {
        widget.onSave(cat);
      }
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final masterList =
        widget.isExpense ? expenseMasterCategories : incomeMasterCategories;
    final activeNames = widget.currentCategories
        .map((c) => c.name.toLowerCase().trim())
        .toSet();

    // Filter available categories that have not yet been added
    final availableCategories = masterList
        .where((name) => !activeNames.contains(name.toLowerCase().trim()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        title: Text(
          widget.isExpense ? 'Add Expense Category' : 'Add Income Category',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: availableCategories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.accentGreen,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All Categories Added',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have already added all available ${widget.isExpense ? 'expense' : 'income'} categories.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'Select from available categories',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: availableCategories.length,
                    itemBuilder: (context, index) {
                      final categoryName = availableCategories[index];
                      final isSelected =
                          _selectedCategories.contains(categoryName);
                      final iconPath = getIconPath(categoryName);

                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.accentGreen
                                : Colors.grey.shade200,
                            width: isSelected ? 1.6 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCategories.remove(categoryName);
                              } else {
                                _selectedCategories.add(categoryName);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentGreen.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SvgPicture.asset(
                                    iconPath,
                                    width: 22,
                                    height: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    categoryName,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accentGreen
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentGreen
                                          : Colors.grey.shade400,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedCategories.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveSelectedCategories,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Add ${_selectedCategories.length} ${_selectedCategories.length == 1 ? 'Category' : 'Categories'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
