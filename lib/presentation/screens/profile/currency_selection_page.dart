// lib/currency_selection_page.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../common/currency_provider.dart';
import '../../../common/hive_storage.dart';
import '../../../models/setup_data.dart';
import '../../../theme/app_colors.dart';

class CurrencySelectionPage extends StatefulWidget {
  const CurrencySelectionPage({super.key});

  @override
  State<CurrencySelectionPage> createState() => _CurrencySelectionPageState();
}

class _CurrencySelectionPageState extends State<CurrencySelectionPage> {
  List<Map<String, dynamic>> _allCurrencies = [];
  List<Map<String, dynamic>> _filteredCurrencies = [];

  String? _selectedCurrencyCode;
  String? _initialCurrencyCode;

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _hasChanges => _initialCurrencyCode != _selectedCurrencyCode;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _searchController.addListener(_filterCurrencies);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialCurrencyCode == null) {
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      _initialCurrencyCode = provider.currencyCode;
      _selectedCurrencyCode = provider.currencyCode;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCurrencies);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    final jsonString = await rootBundle.loadString(
      'assets/json/currencies_with_flags.json',
    );
    final List<dynamic> jsonData = json.decode(jsonString);
    _allCurrencies = List<Map<String, dynamic>>.from(jsonData);

    _allCurrencies.sort((a, b) {
      if (a['currencyCode'] == "INR") return -1;
      if (b['currencyCode'] == "INR") return 1;
      return a['currencyCode'].compareTo(b['currencyCode']);
    });

    setState(() {
      _filteredCurrencies = _allCurrencies;
      _isLoading = false;
    });
  }

  void _filterCurrencies() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCurrencies = _allCurrencies.where((currency) {
        final country = currency['country'].toString().toLowerCase();
        final currencyCode = currency['currencyCode'].toString().toLowerCase();
        final currencySymbol = currency['currencySymbol']
            .toString()
            .toLowerCase();
        return country.contains(query) ||
            currencyCode.contains(query) ||
            currencySymbol.contains(query);
      }).toList();
    });
  }

  String _countryCodeToEmoji(String countryCode) {
    if (countryCode == 'EU') return '🇪🇺';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }

  void _onCurrencySelected(String? newCurrencyCode) {
    setState(() {
      _selectedCurrencyCode = newCurrencyCode;
    });
  }

  Future<void> _saveChanges() async {
    if (_selectedCurrencyCode == null || _isSaving) return;

    setState(() {
      _isSaving = true; // Start loading
    });

    // Show an indefinite snackbar indicating progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(width: 16),
            Text('Updating Currency...'),
          ],
        ),
        duration: const Duration(minutes: 1), // Will be dismissed manually
        backgroundColor: AppColors.accentGreen,
      ),
    );

    try {
      final selectedCurrencyData = _allCurrencies.firstWhere(
        (c) => c['currencyCode'] == _selectedCurrencyCode,
        orElse: () => {},
      );

      if (selectedCurrencyData.isEmpty) return;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final currentSetupData = HiveStorage.getSetupData();
      if (currentSetupData == null) throw Exception('Setup data not found');

      final updatedSetupData = SetupData(
        currencyCode: selectedCurrencyData['currencyCode'],
        currencySymbol: selectedCurrencyData['currencySymbol'],
        country: selectedCurrencyData['country'],
        financialGoal: currentSetupData.financialGoal,
        expenseCategories: currentSetupData.expenseCategories,
        incomeCategories: currentSetupData.incomeCategories,
        timestamp: currentSetupData.timestamp,
        userId: currentSetupData.userId,
      );

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('SetupData')
          .doc(userId)
          .set(updatedSetupData.toMap(), SetOptions(merge: true));

      // Save to Hive
      await HiveStorage.saveSetupData(updatedSetupData);

      // Update provider
      final provider = Provider.of<CurrencyProvider>(context, listen: false);
      await provider.loadCurrency();

      setState(() {
        _initialCurrencyCode = _selectedCurrencyCode;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Dismiss loading snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Currency updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).hideCurrentSnackBar(); // Dismiss loading snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save currency: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // This will run whether the try block succeeds or fails.
      if (mounted) {
        setState(() {
          _isSaving = false; // Stop loading
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundScaffold,
      appBar: AppBar(
        title: const Text('Select Currency'),
        backgroundColor: AppColors.backgroundScaffold,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Currency',
                      hintText: 'e.g., India, USD, €',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency = _filteredCurrencies[index];
                      final currencyCode = currency['currencyCode'] as String;

                      // --- MODIFICATION START ---
                      // Replaced RadioListTile with a standard ListTile for custom layout
                      return ListTile(
                        // 1. Flag on the left
                        leading: Text(
                          _countryCodeToEmoji(currency['countryCode']),
                          style: const TextStyle(fontSize: 30),
                        ),

                        // 2. Title and Subtitle in the middle
                        title: Text(
                          '${currency['currencyCode']} (${currency['currencySymbol']})',
                        ),
                        subtitle: Text(currency['country']),

                        // 3. Radio button on the right
                        trailing: Radio<String>(
                          value: currencyCode,
                          groupValue: _selectedCurrencyCode,
                          onChanged: _isSaving ? null : _onCurrencySelected,
                        ),

                        // 4. Make the entire row tappable
                        onTap: _isSaving
                            ? null
                            : () {
                                _onCurrencySelected(currencyCode);
                              },
                      );
                      // --- MODIFICATION END ---
                    },
                  ),
                ),
                Visibility(
                  visible: _hasChanges,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 20.0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      // Give a fixed height to prevent layout jump
                      child:
                          // --- MODIFICATION START ---
                          // 5. Conditionally show the save button or a progress indicator.
                          // Also hide the button if there are no changes or if saving is in progress.
                          _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : Visibility(
                              visible: _hasChanges,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16.0,
                                  ),
                                  backgroundColor: AppColors.accentGreen,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _saveChanges,
                                child: const Text('Save'),
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
