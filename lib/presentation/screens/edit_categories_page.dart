// lib/edit_categories_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common/hive_storage.dart';
import '../../common/premium_constants.dart';
import '../../models.dart';
import '../../models/category.dart';
import '../../services/premium_service.dart';
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

        title: const Text('Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
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
        onPressed: _onFabPressed,
        child: const Icon(Icons.add),
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
          onSave: (category) async {
            if (existingCategory != null) {
              await _updateCategory(existingCategory, category);
            } else {
              await _addCategory(category);
            }
          },
        ),
      ),
    );
  }

  Future<void> _addCategory(Category category) async {
    try {
      // Check for duplicates
      final existingNames = _categories.map((cat) => cat.name.toLowerCase()).toList();
      if (existingNames.contains(category.name.toLowerCase())) {
        _showErrorSnackBar('Category "${category.name}" already exists');
        return;
      }

      // Check category limit
      final isPremium = PremiumService.instance.isPremium;
      final maxCategories = isPremium 
          ? PremiumConstants.PREMIUM_MAX_CATEGORIES 
          : PremiumConstants.FREE_MAX_CATEGORIES;
      
      if (_categories.length >= maxCategories) {
        _showErrorSnackBar(
          'Category limit reached. You can have up to $maxCategories ${widget.transactionType == TransactionType.expense ? 'expense' : 'income'} categories.${isPremium ? '' : ' Upgrade to Premium for ${PremiumConstants.PREMIUM_MAX_CATEGORIES} categories.'}'
        );
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
      padding: const EdgeInsets.all(16.0),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                category.iconPath,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                width: 20,
                height: 20,
              ),
            ),
            title: Text(
              category.displayName,
              style: const TextStyle(color: Colors.black87,fontWeight: FontWeight.bold),
            ),
            // subtitle: Text(
            //   'Position: ${category.position}',
            //   style: TextStyle(color: Colors.grey.shade400),
            // ),
            // Only show the menu if there is more than one category
            trailing: () {
              if (category.name.toLowerCase() == 'other') {
                return IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("'Others' category cannot be modified."),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                );
              }

              // For other categories, show the menu only if there is more than one category.
              if (_categories.length > 1) {
                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (String result) {
                    if (result == 'edit') {
                      showAddOrEditCategoryDialog(existingCategory: category);
                    } else if (result == 'delete') {
                      _deleteCategory(category);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                );
              }

              // Otherwise, render nothing.
              return null;
            }(), // Immediately execute this anonymous function
// Render nothing if only one category exists
          ),
        );
      },
    );
  }
}