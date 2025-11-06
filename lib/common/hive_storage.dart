import 'package:hive_flutter/hive_flutter.dart';
import '../models/setup_data.dart';
import '../models/hive_transaction.dart';
import '../models/category.dart';
import '../models/account.dart';

class HiveStorage {
  static const String _setupDataBoxName = 'setup_data';
  static const String _userSetupKey = 'user_setup';
  static const String _userProfileBoxName = 'user_profile';
  static const String _userNameKey = 'name';
  static const String _userEmailKey = 'email';
  static const String _userIdKey = 'userId';

  static Box<SetupData>? _setupDataBox;
  static Box? _userProfileBox;

  /// Initialize Hive and open boxes
  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters (only if not already registered)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SetupDataAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveTransactionAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(CategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(AccountAdapter()); // Register Account adapter (typeId: 3)
    }
    
    // Open boxes
    _setupDataBox = await Hive.openBox<SetupData>(_setupDataBoxName);
    _userProfileBox = await Hive.openBox(_userProfileBoxName);
  }

  /// Save setup data to Hive
  static Future<void> saveSetupData(SetupData setupData) async {
    if (_setupDataBox == null) {
      throw Exception('HiveStorage not initialized. Call init() first.');
    }
    
    await _setupDataBox!.put(_userSetupKey, setupData);
  }

  /// Get setup data from Hive
  static SetupData? getSetupData() {
    if (_setupDataBox == null) {
      return null;
    }
    
    return _setupDataBox!.get(_userSetupKey);
  }

  /// Check if setup data exists
  static bool hasSetupData() {
    if (_setupDataBox == null) {
      return false;
    }
    
    return _setupDataBox!.containsKey(_userSetupKey);
  }

  /// Delete setup data
  static Future<void> deleteSetupData() async {
    if (_setupDataBox == null) {
      return;
    }
    
    await _setupDataBox!.delete(_userSetupKey);
  }

  /// Save user profile (simple strings, no adapter needed)
  static Future<void> saveUserProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    if (_userProfileBox == null) {
      throw Exception('HiveStorage not initialized. Call init() first.');
    }
    await _userProfileBox!.put(_userIdKey, userId);
    await _userProfileBox!.put(_userNameKey, name);
    await _userProfileBox!.put(_userEmailKey, email);
  }

  static String getUserName() {
    return (_userProfileBox?.get(_userNameKey) as String?) ?? '';
  }

  static String getUserEmail() {
    return (_userProfileBox?.get(_userEmailKey) as String?) ?? '';
  }

  static String getUserId() {
    return (_userProfileBox?.get(_userIdKey) as String?) ?? '';
  }

  /// Clear user profile
  static Future<void> clearUserProfile() async {
    if (_userProfileBox == null) {
      return;
    }
    
    await _userProfileBox!.delete(_userIdKey);
    await _userProfileBox!.delete(_userNameKey);
    await _userProfileBox!.delete(_userEmailKey);
  }

  /// Add a category to the appropriate list
  static Future<void> addCategory(Category category, bool isExpense) async {
    final setupData = getSetupData();
    if (setupData == null) {
      print('HiveStorage.addCategory: SetupData is null');
      return;
    }

    print('HiveStorage.addCategory: Adding "${category.name}" to ${isExpense ? "expense" : "income"} categories');

    final updatedSetupData = SetupData(
      currencyCode: setupData.currencyCode,
      currencySymbol: setupData.currencySymbol,
      country: setupData.country,
      financialGoal: setupData.financialGoal,
      expenseCategories: isExpense
          ? [...setupData.expenseCategories, category]
          : setupData.expenseCategories,
      incomeCategories: !isExpense
          ? [...setupData.incomeCategories, category]
          : setupData.incomeCategories,
      timestamp: setupData.timestamp,
      userId: setupData.userId,
    );

    await saveSetupData(updatedSetupData);
    print('HiveStorage.addCategory: Successfully saved updated SetupData');
  }

  /// Update a category
  /// Update a category
  static Future<void> updateCategory(Category oldCategory, Category newCategory, bool isExpense) async {
    final setupData = getSetupData();
    if (setupData == null) {
      print('HiveStorage.updateCategory: SetupData is null');
      return;
    }

    print('HiveStorage.updateCategory: Updating "${oldCategory.name}" to "${newCategory.name}" in ${isExpense ? "expense" : "income"} categories');

    List<Category> updatedCategories;
    if (isExpense) {
      updatedCategories = List.from(setupData.expenseCategories);
      final index = updatedCategories.indexWhere((cat) => cat.name == oldCategory.name);
      if (index != -1) {
        updatedCategories[index] = newCategory;
        print('HiveStorage.updateCategory: Found expense category at index $index');
      } else {
        print('HiveStorage.updateCategory: Expense category "${oldCategory.name}" not found');
        return;
      }
    } else {
      updatedCategories = List.from(setupData.incomeCategories);
      final index = updatedCategories.indexWhere((cat) => cat.name == oldCategory.name);
      if (index != -1) {
        updatedCategories[index] = newCategory;
        print('HiveStorage.updateCategory: Found income category at index $index');
      } else {
        print('HiveStorage.updateCategory: Income category "${oldCategory.name}" not found');
        return;
      }
    }

    // UPDATED CONSTRUCTOR CALL
    final updatedSetupData = SetupData(
      currencyCode: setupData.currencyCode,
      currencySymbol: setupData.currencySymbol,
      country: setupData.country,
      financialGoal: setupData.financialGoal,
      expenseCategories: isExpense ? updatedCategories : setupData.expenseCategories,
      incomeCategories: !isExpense ? updatedCategories : setupData.incomeCategories,
      timestamp: setupData.timestamp,
      userId: setupData.userId,
    );

    await saveSetupData(updatedSetupData);
    print('HiveStorage.updateCategory: Successfully saved updated SetupData');
  }
  /// Delete a category
  /// Delete a category
  static Future<void> deleteCategory(Category category, bool isExpense) async {
    final setupData = getSetupData();
    if (setupData == null) {
      print('HiveStorage.deleteCategory: SetupData is null');
      return;
    }

    print('HiveStorage.deleteCategory: Deleting "${category.name}" from ${isExpense ? "expense" : "income"} categories');

    List<Category> updatedCategories;
    if (isExpense) {
      updatedCategories = List.from(setupData.expenseCategories);
      final originalLength = updatedCategories.length;
      updatedCategories.removeWhere((cat) => cat.name == category.name);
      if (updatedCategories.length == originalLength) {
        print('HiveStorage.deleteCategory: Expense category "${category.name}" not found');
        return;
      }
    } else {
      updatedCategories = List.from(setupData.incomeCategories);
      final originalLength = updatedCategories.length;
      updatedCategories.removeWhere((cat) => cat.name == category.name);
      if (updatedCategories.length == originalLength) {
        print('HiveStorage.deleteCategory: Income category "${category.name}" not found');
        return;
      }
    }

    // UPDATED CONSTRUCTOR CALL
    final updatedSetupData = SetupData(
      currencyCode: setupData.currencyCode,
      currencySymbol: setupData.currencySymbol,
      country: setupData.country,
      financialGoal: setupData.financialGoal,
      expenseCategories: isExpense ? updatedCategories : setupData.expenseCategories,
      incomeCategories: !isExpense ? updatedCategories : setupData.incomeCategories,
      timestamp: setupData.timestamp,
      userId: setupData.userId,
    );

    await saveSetupData(updatedSetupData);
    print('HiveStorage.deleteCategory: Successfully saved updated SetupData');
  }


  /// Close all boxes
  static Future<void> close() async {
    await _setupDataBox?.close();
    await _userProfileBox?.close();
  }


}
