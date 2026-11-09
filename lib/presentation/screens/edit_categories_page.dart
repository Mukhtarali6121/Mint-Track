// lib/edit_categories_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/hive_storage.dart';
import '../../models.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';
import 'add_edit_category_page.dart';

// Convert to StatefulWidget to manage state for the FAB
class EditCategoriesPage extends StatefulWidget {
  const EditCategoriesPage({super.key});

  @override
  State<EditCategoriesPage> createState() => _EditCategoriesPageState();
}

class _EditCategoriesPageState extends State<EditCategoriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // GlobalKeys to access the state of the child CategoryListTab widgets
  final GlobalKey<_CategoryListTabState> _expenseTabKey = GlobalKey<_CategoryListTabState>();
  final GlobalKey<_CategoryListTabState> _incomeTabKey = GlobalKey<_CategoryListTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onFabPressed() {
    if (_tabController.index == 0) {
      _expenseTabKey.currentState?.showAddOrEditCategoryDialog();
    } else {
      _incomeTabKey.currentState?.showAddOrEditCategoryDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGreen,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppColors.accentGreen,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          dividerColor: Colors.grey.shade200,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CategoryListTab(
            key: _expenseTabKey, // Assign the key
            transactionType: TransactionType.expense,
          ),
          CategoryListTab(
            key: _incomeTabKey, // Assign the key
            transactionType: TransactionType.income,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accentGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        onPressed: _onFabPressed,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class CategoryListTab extends StatefulWidget {
  const CategoryListTab({super.key, required this.transactionType});

  final TransactionType transactionType;

  @override
  State<CategoryListTab> createState() => _CategoryListTabState();
}

class _CategoryListTabState extends State<CategoryListTab> {
  // --- Firestore and State Management ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DocumentReference _docRef;
  late List<Category> _categories;
  late String _firestoreArrayName;

  @override
  void initState() {
    super.initState();
    _categories = [];
    // Determine the correct field name for Firestore based on transaction type
    _firestoreArrayName =
    widget.transactionType == TransactionType.expense
        ? 'ExpenseCategories'
        : 'IncomeCategories';

    // IMPORTANT: Replace with your actual logic to get the user's document ID
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Handle the case when user is not logged in
      print("⚠️ No user logged in!");
    } else {
      final userId = user.uid;
      debugPrint("🔥 User ID: $userId");
      _docRef = _firestore.collection('SetupData').doc(userId);
    }

    _loadCategories();
  }

  // --- Data Loading ---
  void _loadCategories() {
    final setupData = HiveStorage.getSetupData();
    if (setupData == null) {
      setState(() => _categories = []);
      return;
    }

    final categories = widget.transactionType == TransactionType.expense
        ? setupData.expenseCategories
        : setupData.incomeCategories;

    // Make a copy and sort so "Others" or "Other" always comes last
    final sortedCategories = List<Category>.from(categories);
    sortedCategories.sort((a, b) {
      if (a.name.toLowerCase() == 'others' || a.name.toLowerCase() == 'other') return 1;
      if (b.name.toLowerCase() == 'others' || b.name.toLowerCase() == 'other') return -1;
      return 0;
    });

    setState(() {
      _categories = sortedCategories;
    });
  }

  // --- CRUD Operations ---

  /// Navigates to the add/edit category page
  void showAddOrEditCategoryDialog({Category? existingCategory}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditCategoryPage(
          existingCategory: existingCategory,
          isExpense: widget.transactionType == TransactionType.expense,
          currentCategories: _categories,
          onSave: (category) async {
            if (existingCategory != null) {
              await _updateCategory(existingCategory, category);
            } else {
              await _addCategory(category);
            }
          },
          onAddMultiple: (newCategories) async {
            await _addCategories(newCategories);
          },
        ),
      ),
    );
  }

  Future<void> _addCategories(List<Category> newCategories) async {
    if (newCategories.isEmpty) return;
    try {
      _showLoadingSnackBar(newCategories.length == 1
          ? 'Adding category...'
          : 'Adding ${newCategories.length} categories...');

      final categoryMaps = newCategories.map((c) => c.toMap()).toList();
      await _docRef.update({
        _firestoreArrayName: FieldValue.arrayUnion(categoryMaps),
      });

      for (final cat in newCategories) {
        await HiveStorage.addCategory(
          cat,
          widget.transactionType == TransactionType.expense,
        );
      }

      _loadCategories();
      _showSuccessSnackBar(newCategories.length == 1
          ? 'Category "${newCategories.first.name}" added successfully'
          : '${newCategories.length} categories added successfully');
    } catch (e) {
      debugPrint("Error adding categories: $e");
      _showErrorSnackBar('Failed to add categories: ${e.toString()}');
    }
  }

  Future<void> _addCategory(Category category) async {
    try {
      // Check for duplicates
      final existingNames = _categories.map((cat) => cat.name.toLowerCase()).toList();
      if (existingNames.contains(category.name.toLowerCase())) {
        _showErrorSnackBar('Category "${category.name}" already exists');
        return;
      }

      // Show loading indicator
      _showLoadingSnackBar('Adding category...');

      // 1. Update Firestore
      await _docRef.update({
        _firestoreArrayName: FieldValue.arrayUnion([category.toMap()])
      });
      
      // 2. Update Hive
      await HiveStorage.addCategory(category, widget.transactionType == TransactionType.expense);

      // 3. Refresh UI from local data source
      _loadCategories();
      
      // Show success message
      _showSuccessSnackBar('Category "${category.name}" added successfully');
    } catch (e) {
      print("Error adding category: $e");
      _showErrorSnackBar('Failed to add category: ${e.toString()}');
    }
  }

  Future<void> _updateCategory(Category oldCategory, Category newCategory) async {
    try {
      // Check for duplicates (excluding the current category being edited)
      final existingNames = _categories
          .where((cat) => cat.name.toLowerCase() != oldCategory.name.toLowerCase())
          .map((cat) => cat.name.toLowerCase())
          .toList();
      
      if (existingNames.contains(newCategory.name.toLowerCase())) {
        _showErrorSnackBar('Category "${newCategory.name}" already exists');
        return;
      }

      // Show loading indicator
      _showLoadingSnackBar('Updating category...');

      // For arrays, we must read, modify, and write the entire array back
      final docSnapshot = await _docRef.get();
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        _showErrorSnackBar('Failed to load category data');
        return;
      }

      List<Map<String, dynamic>> currentCategories = List<Map<String, dynamic>>.from(data[_firestoreArrayName] ?? []);
      final index = currentCategories.indexWhere((cat) => cat['name'] == oldCategory.name);
      if(index != -1) {
        currentCategories[index] = newCategory.toMap();

        // 1. Update Firestore
        await _docRef.update({_firestoreArrayName: currentCategories});

        // 2. Update Hive
        await HiveStorage.updateCategory(oldCategory, newCategory, widget.transactionType == TransactionType.expense);

        // 3. Refresh UI
        _loadCategories();
        
        // Show success message
        _showSuccessSnackBar('Category updated successfully');
      } else {
        _showErrorSnackBar('Category not found');
      }
    } catch (e) {
      print("Error updating category: $e");
      _showErrorSnackBar('Failed to update category: ${e.toString()}');
    }
  }

  Future<void> _deleteCategory(Category category) async {
    // Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Show loading indicator
        _showLoadingSnackBar('Deleting category...');

        // For arrays, we must read, modify, and write the entire array back
        final docSnapshot = await _docRef.get();
        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          _showErrorSnackBar('Failed to load category data');
          return;
        }

        List<Map<String, dynamic>> currentCategories = List<Map<String, dynamic>>.from(data[_firestoreArrayName] ?? []);
        currentCategories.removeWhere((cat) => cat['name'] == category.name);

        // 1. Update Firestore
        await _docRef.update({_firestoreArrayName: currentCategories});

        // 2. Update Hive
        await HiveStorage.deleteCategory(category, widget.transactionType == TransactionType.expense);

        // 3. Refresh UI
        _loadCategories();
        
        // Show success message
        _showSuccessSnackBar('Category "${category.name}" deleted successfully');
      } catch (e) {
        print("Error deleting category: $e");
        _showErrorSnackBar('Failed to delete category: ${e.toString()}');
      }
    }
  }

  // --- Helper Methods for User Feedback ---
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- UI Widgets ---
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 88),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isWhiteBg = category.colorValue == Colors.white.value ||
            category.colorValue == 0xFFFFFFFF ||
            category.color == Colors.white;

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
              color: Colors.grey.shade200,
              width: 1.0,
            ),
          ),
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
                    color: isWhiteBg
                        ? AppColors.accentGreen.withValues(alpha: 0.12)
                        : category.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(
                    category.iconPath,
                    colorFilter: isWhiteBg
                        ? null
                        : const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                    width: 22,
                    height: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    category.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Trailing menu action
                if (category.name.toLowerCase() == 'other' ||
                    category.name.toLowerCase() == 'others')
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("'Others' category cannot be modified."),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  )
                else if (_categories.length > 1)
                  Theme(
                    data: Theme.of(context).copyWith(cardColor: Colors.white),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: Colors.grey.shade700,
                        size: 20,
                      ),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      elevation: 3,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      onSelected: (String result) {
                        if (result == 'delete') {
                          _deleteCategory(category);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'delete',
                          height: 40,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}