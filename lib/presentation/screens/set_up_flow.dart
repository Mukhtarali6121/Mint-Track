import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/presentation/screens/set_up_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_ready_screen.dart';
import '../../common/hive_storage.dart';
import '../../common/account_hive_storage.dart';
import '../../models/setup_data.dart';
import '../../models/category.dart';

class SetupFlow extends StatefulWidget {
  const SetupFlow({super.key});

  @override
  State<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends State<SetupFlow> {
  final PageController _controller = PageController();
  final _random = Random();
  List<Map<String, dynamic>> _fullCurrencyData = [];
  List<Map<String, dynamic>> _steps = [];
  bool _isCurrencyLoading = true;
  int _currentStep = 0;
  Map<int, dynamic> _selections = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  /// Load currencies from local JSON and initialize steps
  Future<void> _loadSteps() async {
    try {
      final jsonString = await rootBundle.loadString('assets/json/currencies_with_flags.json');
      // Cast to the correct type
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
          "Choose the categories you usually spend on, such as food, transportation, or entertainment.",
          "options": [
            "Food",
            "Drinks",
            "Transportation",
            "Housing",
            "Shopping",
            "Health",
            "Fitness",
            "Entertainment",
            "Games",
            "Education",
            // "Debt",
            "Loans",
            "Savings",
            "Investments",
            "Travel",
            "Gifts",
            "Donations",
            "Beauty",
            "Taxes",
          ],
          "multiSelect": true,
        },
        {
          "title": "Select Income Categories",
          "subtitle":
          "Choose your income sources such as salary, freelancing, or investments.",
          "options": [
            "Salary",
            "Business",
            "Interest Income",
            "Gifts",
            "Rental Income",
          ],
          "multiSelect": true,
        },
      ];

      setState(() => _isCurrencyLoading = false);
    } catch (e) {
      print("Error loading currency JSON: $e");
    }
  }

  /// Convert country code (e.g., 'IN') → flag emoji 🇮🇳
  String _countryCodeToEmoji(String code) {
    return code.toUpperCase().replaceAllMapped(RegExp(r'[A-Z]'),
            (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397));
  }

  // --- Your existing logic from here remains unchanged ---
  void _nextStep(dynamic selected) async {
    _selections[_currentStep] = selected;

    if (_currentStep < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // --- MODIFIED SAVE LOGIC ---
      setState(() => _isLoading = true);
      final userId = FirebaseAuth.instance.currentUser?.uid ?? "dummyUserId";

      // 1. Find the full currency map from the selected display string
      final selectedCurrencyString = _selections[0] as String;

      // 2. Parse the string to reliably get the currency code
      final parts = selectedCurrencyString.split(' ');
      // The currency code will be the second part of the string
      final selectedCode = parts.length > 1 ? parts[1] : '';

      final selectedCurrencyData = _fullCurrencyData.firstWhere(
            (currency) => currency['currencyCode'] == selectedCode,
        // Provide a fallback in case no match is found
        orElse: () => {
          'country': 'Unknown',
          'currencyCode': 'N/A',
          'currencySymbol': ''
        },
      );


      // 2. Prepare the currency data map to be saved
      final currencyDataForDb = {
        'country': selectedCurrencyData['country'],
        'currencyCode': selectedCurrencyData['currencyCode'],
        'currencySymbol': selectedCurrencyData['currencySymbol'],
      };

      final expenseCategories = _createCategoriesFromStrings(_selections[2], true);
      final incomeCategories = _createCategoriesFromStrings(_selections[3], false);

      // 3. Update the Firestore data map
      final Map<String, dynamic> setupData = {
        "Currency": currencyDataForDb, // Use the map here
        "FinancialGoal": _selections[1],
        "ExpenseCategories": expenseCategories.map((cat) => cat.toMap()).toList(),
        "IncomeCategories": incomeCategories.map((cat) => cat.toMap()).toList(),
        "timestamp": FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance.collection('SetupData').doc(userId).set(setupData);

        // 4. Update the Hive object
        // NOTE: You'll need to update your `SetupData` model to accept these new fields.
        // For example, from `String currency` to:
        // String currencyCode;
        // String currencySymbol;
        // String country;
        final setupDataForHive = SetupData(
          currencyCode: selectedCurrencyData['currencyCode'] ?? 'N/A',
          currencySymbol: selectedCurrencyData['currencySymbol'] ?? '',
          country: selectedCurrencyData['country'] ?? 'Unknown',
          financialGoal: _selections[1],
          expenseCategories: expenseCategories,
          incomeCategories: incomeCategories,
          timestamp: DateTime.now(),
          userId: userId,
        );
        await HiveStorage.saveSetupData(setupDataForHive);
        print("Setup data saved successfully to both Firestore and Hive");

        // Create default Cash account for new user
        await AccountHiveStorage.init();
        await AccountHiveStorage.initializeDefaultCashAccount();
        print("Default Cash account created for new user");

        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AccountReadyScreen()),
          );
        }
      } catch (e) {
        print("Error saving setup data: $e");
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Failed to save setup data')));
          setState(() => _isLoading = false);
        }
      }
    }
  }


  void _skipStep() {
    if (_currentStep < _steps.length - 1) {
      _controller.jumpToPage(_steps.length - 1);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Setup Skipped!')));
    }
  }

  List<Category> _createCategoriesFromStrings(List<String> categoryNames, bool isExpense) {
    final categories = <Category>[];
    for (int i = 0; i < categoryNames.length; i++) {
      categories.add(Category(
        name: categoryNames[i],
        iconName: categoryNames[i].toLowerCase(),
        colorValue: _getRandomLightColor().value,
        position: i,
      ));
    }
    categories.add(Category(
      name: "Other",
      iconName: "others",
      colorValue: _getRandomLightColor().value,
      position: categories.length,
    ));
    return categories;
  }

  Color _getRandomLightColor() {
    final mixedVibrantColors = [
      Colors.blue.shade300,
      Colors.lightBlue.shade300,
      Colors.green.shade300,
      Colors.lightGreen.shade300,
      Colors.lime.shade300,
      Colors.yellow.shade300,
      Colors.orange.shade300,
      Colors.deepOrange.shade300,
      Colors.pink.shade300,
      Colors.purple.shade300,
      Colors.cyan.shade300,
      Colors.teal.shade300,
      Colors.amber.shade300,
      Colors.indigo.shade400,
      Colors.orange.shade400,
      Colors.purple.shade700,
      Colors.red.shade700,
      Colors.indigo.shade700,
      Colors.blueGrey.shade700,
      Colors.teal.shade800,
      Colors.deepPurple.shade700,
      Colors.brown.shade700,
    ]..shuffle(_random);

    return mixedVibrantColors.first;
  }

  @override
  Widget build(BuildContext context) {
    if (_isCurrencyLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _currentStep = index),
          itemCount: _steps.length,
          itemBuilder: (context, index) {
            final step = _steps[index];
            return SetupScreen(
              title: step['title'],
              subtitle: step['subtitle'],
              options: List<String>.from(step['options']),
              multiSelect: step['multiSelect'],
              currentStep: index + 1,
              totalSteps: _steps.length,
              onNext: _nextStep,
              onSkip: _skipStep,
              onBack: () {
                if (_currentStep > 0) {
                  _controller.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
              previousSelection: _selections[index], // restore selection

            );
          },
        ),

        if (_isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
