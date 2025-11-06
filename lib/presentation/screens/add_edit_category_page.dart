import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';

class AddEditCategoryPage extends StatefulWidget {
  final Category? existingCategory;
  final bool isExpense;
  final Function(Category) onSave;

  const AddEditCategoryPage({
    super.key,
    this.existingCategory,
    required this.isExpense,
    required this.onSave,
  });

  @override
  State<AddEditCategoryPage> createState() => _AddEditCategoryPageState();
}

class _AddEditCategoryPageState extends State<AddEditCategoryPage> {
  late TextEditingController _nameController;
  late String _selectedIcon;
  late Color _selectedColor;
  late int _selectedPosition;

  final List<String> _availableIcons = [
    'food', 'drinks', 'transportation', 'housing', 'shopping',
    'health', 'fitness', 'entertainment', 'games', 'education',
    'loans', 'savings', 'investments', 'travel', 'gifts',
    'donations', 'beauty', 'taxes', 'salary', 'business',
    'interest income', 'rental income', 'others'
  ];

  final List<Color> _availableColors = [
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
    Colors.red.shade200,
    Colors.deepOrange.shade200,
    Colors.deepPurple.shade200,
    Colors.lightBlue.shade200,
    Colors.lightGreen.shade200,
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingCategory?.name ?? '',
    );
    _selectedIcon = widget.existingCategory?.iconName ?? 'category';
    _selectedColor = widget.existingCategory?.color ?? Colors.blue.shade200;
    _selectedPosition = widget.existingCategory?.position ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _getIconPath(String iconName) {
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

    return iconMap[iconName.toLowerCase()] ?? 'assets/images/ic_vector_other.svg';
  }

  void _saveCategory() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot be empty')),
      );
      return;
    }

    final category = Category(
      name: name,
      iconName: _selectedIcon,
      colorValue: _selectedColor.value,
      position: _selectedPosition,
    );

    widget.onSave(category);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingCategory != null;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Category' : 'Add Category'),
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saveCategory,
            child: Text(
              isEditing ? 'Save' : 'Add',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Name Section
            const Text(
              'Category Name',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter category name',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade800,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Preview Section
            const Text(
              'Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SvgPicture.asset(
                      _getIconPath(_selectedIcon),
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _nameController.text.isEmpty ? 'Category Name' : _nameController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Color Selection Section
            const Text(
              'Select Color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableColors.length,
                itemBuilder: (context, index) {
                  final color = _availableColors[index];
                  final isSelected = _selectedColor == color;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Icon Selection Section
            const Text(
              'Select Icon',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final iconName = _availableIcons[index];
                  final isSelected = _selectedIcon == iconName;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = iconName;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedColor : Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: SvgPicture.asset(
                          _getIconPath(iconName),
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Position Section (only for editing)
            // if (isEditing) ...[
            //   const Text(
            //     'Position',
            //     style: TextStyle(
            //       fontSize: 18,
            //       fontWeight: FontWeight.bold,
            //       color: Colors.black87,
            //     ),
            //   ),
            //   const SizedBox(height: 8),
            //   Container(
            //     padding: const EdgeInsets.all(16),
            //     decoration: BoxDecoration(
            //       color: Colors.grey.shade800,
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: Row(
            //       children: [
            //         const Text(
            //           'Position: ',
            //           style: TextStyle(color: Colors.white),
            //         ),
            //         Expanded(
            //           child: Slider(
            //             value: _selectedPosition.toDouble(),
            //             min: 0,
            //             max: 10,
            //             divisions: 10,
            //             activeColor: _selectedColor,
            //             inactiveColor: Colors.grey.shade600,
            //             onChanged: (value) {
            //               setState(() {
            //                 _selectedPosition = value.round();
            //               });
            //             },
            //           ),
            //         ),
            //         Text(
            //           _selectedPosition.toString(),
            //           style: const TextStyle(color: Colors.white),
            //         ),
            //       ],
            //     ),
            //   ),
            // ],
            //
          ],
        ),
      ),
    );
  }
}
