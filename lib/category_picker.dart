import 'package:expense_tracker/presentation/screens/edit_categories_page.dart';
import 'package:expense_tracker/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models.dart';
import 'models/category.dart';
import 'common/hive_storage.dart';

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

class _CategoryPickerBottomSheetState
    extends State<CategoryPickerBottomSheet> {
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
        Category(name: 'Food', iconName: 'food', colorValue: 0xFF81C784, position: 0),
        Category(name: 'Drinks', iconName: 'drinks', colorValue: 0xFF64B5F6, position: 1),
        Category(name: 'Transportation', iconName: 'transportation', colorValue: 0xFF2196F3, position: 2),
        Category(name: 'Housing', iconName: 'housing', colorValue: 0xFF795548, position: 3),
        Category(name: 'Shopping', iconName: 'shopping', colorValue: 0xFFFFB74D, position: 4),
        Category(name: 'Health', iconName: 'health', colorValue: 0xFFE57373, position: 5),
        Category(name: 'Fitness', iconName: 'fitness', colorValue: 0xFF4CAF50, position: 6),
        Category(name: 'Entertainment', iconName: 'entertainment', colorValue: 0xFFBA68C8, position: 7),
        Category(name: 'Games', iconName: 'games', colorValue: 0xFF9C27B0, position: 8),
        Category(name: 'Education', iconName: 'education', colorValue: 0xFF3F51B5, position: 9),
        Category(name: 'Loans', iconName: 'loans', colorValue: 0xFF607D8B, position: 10),
        Category(name: 'Savings', iconName: 'savings', colorValue: 0xFF4CAF50, position: 11),
        Category(name: 'Investments', iconName: 'investments', colorValue: 0xFF8BC34A, position: 12),
        Category(name: 'Travel', iconName: 'travel', colorValue: 0xFF00BCD4, position: 13),
        Category(name: 'Gifts', iconName: 'gifts', colorValue: 0xFFE91E63, position: 14),
        Category(name: 'Donations', iconName: 'donations', colorValue: 0xFF9C27B0, position: 15),
        Category(name: 'Beauty', iconName: 'beauty', colorValue: 0xFFE1BEE7, position: 16),
        Category(name: 'Taxes', iconName: 'taxes', colorValue: 0xFFFF5722, position: 17),
        Category(name: 'Others', iconName: 'others', colorValue: 0xFF90A4AE, position: 18),
      ];
    } else {
      return [
        Category(name: 'Salary', iconName: 'salary', colorValue: 0xFF4CAF50, position: 0),
        Category(name: 'Business', iconName: 'business', colorValue: 0xFF2196F3, position: 1),
        Category(name: 'Interest Income', iconName: 'interest income', colorValue: 0xFF8BC34A, position: 2),
        Category(name: 'Gifts', iconName: 'gifts', colorValue: 0xFFE91E63, position: 3),
        Category(name: 'Rental Income', iconName: 'rental income', colorValue: 0xFF795548, position: 4),
        Category(name: 'Others', iconName: 'others', colorValue: 0xFF90A4AE, position: 5),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _getCategoriesFromHive();
    print("aaksjdnad==> $categories");
    categories.sort((a, b) {
      if (a.name.toLowerCase() == 'others' || a.name.toLowerCase() == 'other') return 1; // push a after b
      if (b.name == 'Others'|| b.name.toLowerCase() == 'other') return -1; // push b after a
      return 0;
    });


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundScaffold,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select ${widget.transactionType.name} Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, // or FontWeight.w600, etc.
                  fontSize: 19
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Then push the new page onto the stack
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EditCategoriesPage(),
                    ),
                  );

                },
                icon: const Icon(Icons.edit, size: 20),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          )
,
          const SizedBox(height: 16),

          // GridView with limited height
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 3 items per row
                childAspectRatio: 0.8, // more height for text below
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = widget.selectedCategory == category.name;

                return InkWell(
                  onTap: () {
                    widget.onCategorySelected(category.name);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circle icon
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: category.color, width: 2)
                              : null,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12), // space inside the circle
                          child: SvgPicture.asset(
                            category.iconPath,
                            colorFilter: ColorFilter.mode(
                              category.color,
                              BlendMode.srcIn,
                            ),
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Category name
                      Text(
                        category.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? category.color
                              : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
