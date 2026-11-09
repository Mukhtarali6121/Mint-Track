import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/account_hive_storage.dart';
import '../../common/hive_storage.dart';
import '../../models/category.dart';
import '../../models/setup_data.dart';
import '../../theme/app_colors.dart';
import 'account_ready_screen.dart';

class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  final PageController _controller = PageController();
  List<Map<String, dynamic>> _fullCurrencyData = [];
  List<Map<String, dynamic>> _steps = [];
  bool _isCurrencyLoading = true;
  int _currentStep = 0;
  final Map<int, dynamic> _selections = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint("👉 [SetupFlow] initState initialized");
    _loadSteps();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Category name to SVG asset path mapping
  String? _getCategorySvgPath(String name) {
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
    return iconMap[name.toLowerCase().trim()];
  }

  /// Load currencies from local JSON and initialize steps
  Future<void> _loadSteps() async {
    debugPrint("👉 [SetupFlow] Loading steps and currencies...");
    try {
      final jsonString = await rootBundle.loadString(
        'assets/json/currencies_with_flags.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);
      _fullCurrencyData = List<Map<String, dynamic>>.from(jsonData);

      // Sort the full data list to ensure INR is at the top
      _fullCurrencyData.sort((a, b) {
        if (a['currencyCode'].contains("INR")) return -1;
        if (b['currencyCode'].contains("INR")) return 1;
        return a['currencyCode'].compareTo(b['currencyCode']);
      });

      // Create display strings from the now-sorted full data list
      final List<String> currencyOptions = _fullCurrencyData.map((e) {
        final flag = _countryCodeToEmoji(e['countryCode']);
        return "$flag ${e['currencyCode']} (${e['currencySymbol']})";
      }).toList();

      _steps = [
        {
          "title": "Set Your Currency",
          "subtitle":
              "Select the currency you want to use within the app to easily track your expenses and income.",
          "options": currencyOptions,
          "multiSelect": false,
        },
        {
          "title": "Select Your Financial Goals",
          "subtitle":
              "Set your financial goals like saving or cutting expenses, and track your progress toward achieving them.",
          "options": [
            "Monthly savings",
            "Reduce expenses",
            "Planning a big purchase",
            "Investing in the future",
            "Track monthly spending",
            "Billing management",
          ],
          "multiSelect": false,
        },
        {
          "title": "Select Expense Categories",
          "subtitle":
              "Choose the categories you usually spend on, such as fuel and transportation, insurance, or personal care.",
          "options": [
            "Insurance",
            "Investment",
            "Fuel and Transportation",
            "Credit Card Bill",
            "Cash Withdrawal",
            "Gifts",
            "Personal Care",
            "Repair",
            "Self Care",
            "Birthdays",
            "Yoga & Meditation",
            "Fitness",
            "Renovation",
            "Bills & Utilities",
            "Groceries",
            "Food & Dining",
            "Entertainment",
            "Hospital",
            "Charges",
            "Tax",
            "Education",
            "Loan",
            "Shopping",
            "Subscription",
            "Travel",
          ],
          "multiSelect": true,
        },
        {
          "title": "Select Income Categories",
          "subtitle":
              "Choose your income sources such as investment, cash withdrawal, or gifts.",
          "options": [
            "Investment",
            "Cash Withdrawal",
            "Gifts",
            "Birthdays",
          ],
          "multiSelect": true,
        },
      ];

      // Pre-select INR for Step 0 if available
      if (_selections[0] == null && currencyOptions.isNotEmpty) {
        _selections[0] = currencyOptions.first;
      }

      debugPrint("✅ [SetupFlow] Setup steps loaded successfully. Total steps: ${_steps.length}");
      if (mounted) setState(() => _isCurrencyLoading = false);
    } catch (e, stack) {
      debugPrint("❌ [SetupFlow] Error loading currency JSON: $e\n$stack");
      if (mounted) setState(() => _isCurrencyLoading = false);
    }
  }

  /// Convert country code (e.g., 'IN') → flag emoji 🇮🇳
  String _countryCodeToEmoji(String code) {
    return code.toUpperCase().replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
    );
  }

  void _onNextPressed() {
    final step = _steps[_currentStep];
    final multiSelect = step['multiSelect'] as bool;
    final selection = _selections[_currentStep];

    if (multiSelect) {
      if (selection == null || (selection is List && selection.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one option')),
        );
        return;
      }
    } else {
      if (selection == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an option')),
        );
        return;
      }
    }

    if (_currentStep < _steps.length - 1) {
      final nextStep = _currentStep + 1;
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = nextStep);
    } else {
      _saveSetupData();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      final prevStep = _currentStep - 1;
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = prevStep);
    }
  }

  Future<void> _saveSetupData() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid ?? "dummyUserId";

    final selectedCurrencyString = (_selections[0] as String?) ?? '';
    final parts = selectedCurrencyString.split(' ');
    final selectedCode = parts.length > 1 ? parts[1] : '';

    final selectedCurrencyData = _fullCurrencyData.firstWhere(
      (currency) => currency['currencyCode'] == selectedCode,
      orElse: () => {
        'country': 'Unknown',
        'currencyCode': 'N/A',
        'currencySymbol': '',
      },
    );

    final currencyDataForDb = {
      'country': selectedCurrencyData['country'],
      'currencyCode': selectedCurrencyData['currencyCode'],
      'currencySymbol': selectedCurrencyData['currencySymbol'],
    };

    final expenseCategories = _createCategoriesFromStrings(
      List<String>.from((_selections[2] as List?) ?? []),
      true,
    );
    final incomeCategories = _createCategoriesFromStrings(
      List<String>.from((_selections[3] as List?) ?? []),
      false,
    );

    final Map<String, dynamic> setupData = {
      "Currency": currencyDataForDb,
      "FinancialGoal": _selections[1],
      "ExpenseCategories": expenseCategories.map((cat) => cat.toMap()).toList(),
      "IncomeCategories": incomeCategories.map((cat) => cat.toMap()).toList(),
      "timestamp": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('SetupData')
          .doc(userId)
          .set(setupData);

      final setupDataForHive = SetupData(
        currencyCode: selectedCurrencyData['currencyCode'] ?? 'N/A',
        currencySymbol: selectedCurrencyData['currencySymbol'] ?? '',
        country: selectedCurrencyData['country'] ?? 'Unknown',
        financialGoal: (_selections[1] as String?) ?? '',
        expenseCategories: expenseCategories,
        incomeCategories: incomeCategories,
        timestamp: DateTime.now(),
        userId: userId,
      );
      await HiveStorage.saveSetupData(setupDataForHive);
      debugPrint("Setup data saved successfully to both Firestore and Hive");

      await AccountHiveStorage.init();
      await AccountHiveStorage.initializeDefaultCashAccount();
      debugPrint("Default Cash account created for new user");

      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountReadyScreen()),
        );
      }
    } catch (e) {
      debugPrint("Error saving setup data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save setup data')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Category> _createCategoriesFromStrings(
    List<String> categoryNames,
    bool isExpense,
  ) {
    final categories = <Category>[];
    for (int i = 0; i < categoryNames.length; i++) {
      categories.add(
        Category(
          name: categoryNames[i],
          iconName: categoryNames[i].toLowerCase(),
          colorValue: Colors.white.value,
          position: i,
        ),
      );
    }
    categories.add(
      Category(
        name: "Other",
        iconName: "others",
        colorValue: Colors.white.value,
        position: categories.length,
      ),
    );
    return categories;
  }

  Widget _buildStepOptions(int stepIndex) {
    final step = _steps[stepIndex];
    final options = List<String>.from(step['options']);
    final multiSelect = step['multiSelect'] as bool;
    final selection = _selections[stepIndex];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: options.map((option) {
          final isSelected = multiSelect
              ? (selection is List && selection.contains(option))
              : (selection == option);
          final iconPath = _getCategorySvgPath(option);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (multiSelect) {
                  final list = selection is List
                      ? List<String>.from(selection)
                      : <String>[];
                  if (list.contains(option)) {
                    list.remove(option);
                  } else {
                    list.add(option);
                  }
                  _selections[stepIndex] = list;
                } else {
                  _selections[stepIndex] = option;
                }
              });
            },
            child: Container(
              width: multiSelect
                  ? (MediaQuery.of(context).size.width - 48 - 12) / 2
                  : double.infinity,
              constraints: BoxConstraints(
                minHeight: multiSelect ? 54 : 50,
              ),
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: multiSelect ? 12 : 18,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentGreen
                    : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppColors.accentGreen
                      : Colors.grey.shade300,
                  width: isSelected ? 1.4 : 1.0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: AppColors.accentGreen.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: iconPath != null
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (iconPath != null) ...[
                    SvgPicture.asset(
                      iconPath,
                      width: 22,
                      height: 22,
                      colorFilter: isSelected
                          ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                          : null,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      option,
                      textAlign:
                          iconPath != null ? TextAlign.left : TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCurrencyLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentStepData = _steps[_currentStep];

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1️⃣ Persistent Animated Progress Bar
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0.0,
                      end: (_currentStep + 1) / _steps.length,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        color: AppColors.accentGreen,
                        backgroundColor: Colors.grey.shade200,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 2️⃣ Smooth in-place Title & Subtitle Fade Switcher
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                    child: Column(
                      key: ValueKey<int>(_currentStep),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStepData['title'] as String,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentStepData['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3️⃣ Middle Options Area (ONLY this middle part slides in the PageView)
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        return _buildStepOptions(index);
                      },
                    ),
                  ),

                  // 4️⃣ Persistent Bottom Area
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      "You can customize later in the app",
                      style: TextStyle(color: Colors.black45, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Center(
                    child: Text(
                      "QUESTION ${_currentStep + 1} OF ${_steps.length}",
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
