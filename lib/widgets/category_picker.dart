import 'package:expense_tracker/presentation/screens/edit_categories_page.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models.dart';
import '../models/category.dart';
import '../common/hive_storage.dart';

class CategoryPickerBottomSheet extends StatefulWidget {
  const CategoryPickerBottomSheet({
    super.key,
    required this.transactionType,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  final TransactionType transactionType;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  State<CategoryPickerBottomSheet> createState() =>
      _CategoryPickerBottomSheetState();
}

class _CategoryPickerBottomSheetState extends State<CategoryPickerBottomSheet> {
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    final categories = _getCategoriesFromHive();
    final initial = widget.selectedCategory;
    if (initial != null) {
      final match = categories.cast<Category?>().firstWhere(
        (c) => c != null && c.name.toLowerCase() == initial.toLowerCase(),
        orElse: () => null,
      );
      _selectedCategory = match?.name;
    } else {
      _selectedCategory = null;
    }
  }

  List<Category> _getCategoriesFromHive() {
    final setupData = HiveStorage.getSetupData();
    if (setupData == null) return _getDefaultCategories();

    final categories = widget.transactionType == TransactionType.expense
        ? setupData.expenseCategories
        : setupData.incomeCategories;

    return List.from(categories);
  }

  List<Category> _getDefaultCategories() {
    if (widget.transactionType == TransactionType.expense) {
      return [
        Category(
          name: 'Insurance',
          iconName: 'insurance',
          colorValue: Colors.white.value,
          position: 0,
        ),
        Category(
          name: 'Investment',
          iconName: 'investment',
          colorValue: Colors.white.value,
          position: 1,
        ),
        Category(
          name: 'Fuel and Transportation',
          iconName: 'fuel and transportation',
          colorValue: Colors.white.value,
          position: 2,
        ),
        Category(
          name: 'Credit Card Bill',
          iconName: 'credit card bill',
          colorValue: Colors.white.value,
          position: 3,
        ),
        Category(
          name: 'Cash Withdrawal',
          iconName: 'cash withdrawal',
          colorValue: Colors.white.value,
          position: 4,
        ),
        Category(
          name: 'Gifts',
          iconName: 'gifts',
          colorValue: Colors.white.value,
          position: 5,
        ),
        Category(
          name: 'Personal Care',
          iconName: 'personal care',
          colorValue: Colors.white.value,
          position: 6,
        ),
        Category(
          name: 'Repair',
          iconName: 'repair',
          colorValue: Colors.white.value,
          position: 7,
        ),
        Category(
          name: 'Self Care',
          iconName: 'self care',
          colorValue: Colors.white.value,
          position: 8,
        ),
        Category(
          name: 'Birthdays',
          iconName: 'birthdays',
          colorValue: Colors.white.value,
          position: 9,
        ),
        Category(
          name: 'Yoga & Meditation',
          iconName: 'yoga & meditation',
          colorValue: Colors.white.value,
          position: 10,
        ),
        Category(
          name: 'Fitness',
          iconName: 'fitness',
          colorValue: Colors.white.value,
          position: 11,
        ),
        Category(
          name: 'Renovation',
          iconName: 'renovation',
          colorValue: Colors.white.value,
          position: 12,
        ),
        Category(
          name: 'Bills & Utilities',
          iconName: 'bills & utilities',
          colorValue: Colors.white.value,
          position: 13,
        ),
        Category(
          name: 'Groceries',
          iconName: 'groceries',
          colorValue: Colors.white.value,
          position: 14,
        ),
        Category(
          name: 'Food & Dining',
          iconName: 'food & dining',
          colorValue: Colors.white.value,
          position: 15,
        ),
        Category(
          name: 'Entertainment',
          iconName: 'entertainment',
          colorValue: Colors.white.value,
          position: 16,
        ),
        Category(
          name: 'Hospital',
          iconName: 'hospital',
          colorValue: Colors.white.value,
          position: 17,
        ),
        Category(
          name: 'Charges',
          iconName: 'charges',
          colorValue: Colors.white.value,
          position: 18,
        ),
        Category(
          name: 'Tax',
          iconName: 'tax',
          colorValue: Colors.white.value,
          position: 19,
        ),
        Category(
          name: 'Education',
          iconName: 'education',
          colorValue: Colors.white.value,
          position: 20,
        ),
        Category(
          name: 'Loan',
          iconName: 'loan',
          colorValue: Colors.white.value,
          position: 21,
        ),
        Category(
          name: 'Shopping',
          iconName: 'shopping',
          colorValue: Colors.white.value,
          position: 22,
        ),
        Category(
          name: 'Subscription',
          iconName: 'subscription',
          colorValue: Colors.white.value,
          position: 23,
        ),
        Category(
          name: 'Travel',
          iconName: 'travel',
          colorValue: Colors.white.value,
          position: 24,
        ),
        Category(
          name: 'Other',
          iconName: 'others',
          colorValue: Colors.white.value,
          position: 25,
        ),
      ];
    } else {
      return [
        Category(
          name: 'Investment',
          iconName: 'investment',
          colorValue: Colors.white.value,
          position: 0,
        ),
        Category(
          name: 'Cash Withdrawal',
          iconName: 'cash withdrawal',
          colorValue: Colors.white.value,
          position: 1,
        ),
        Category(
          name: 'Gifts',
          iconName: 'gifts',
          colorValue: Colors.white.value,
          position: 2,
        ),
        Category(
          name: 'Birthdays',
          iconName: 'birthdays',
          colorValue: Colors.white.value,
          position: 3,
        ),
        Category(
          name: 'Other',
          iconName: 'others',
          colorValue: Colors.white.value,
          position: 4,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _getCategoriesFromHive();
    categories.sort((a, b) {
      if (a.name.toLowerCase() == 'others' || a.name.toLowerCase() == 'other') {
        return 1; // push a after b
      }
      if (b.name.toLowerCase() == 'others' || b.name.toLowerCase() == 'other') {
        return -1; // push b after a
      }
      return 0;
    });

    final hasValidSelection = _selectedCategory != null &&
        categories.any((c) => c.name == _selectedCategory);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 4, bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header: Title & Subtitle + Action buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Categorise this transaction',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tap to categorise',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EditCategoriesPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFF6B7280),
                tooltip: 'Manage categories',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 14),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 22),
                color: const Color(0xFF374151),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid of categories
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.74,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = _selectedCategory == category.name;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category.name;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circle icon
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentGreen.withValues(alpha: 0.12)
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.accentGreen,
                                  width: 2.0,
                                )
                              : Border.all(
                                  color: const Color(0xFFF0F2F5),
                                  width: 1.0,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            category.iconPath,
                            width: 26,
                            height: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Category name
                      SizedBox(
                        height: 32,
                        child: Text(
                          category.displayName,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.accentGreen
                                : const Color(0xFF2D3748),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 12,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Next button at the bottom
          Container(
            width: double.infinity,
            height: 50,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            child: ElevatedButton(
              onPressed: hasValidSelection
                  ? () {
                      widget.onCategorySelected(_selectedCategory!);
                      Navigator.of(context).pop();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen,
                disabledBackgroundColor: const Color(0xFFE5E6E7),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Next',
                style: TextStyle(
                  color: hasValidSelection
                      ? Colors.white
                      : const Color(0xFFBDBFC1),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
