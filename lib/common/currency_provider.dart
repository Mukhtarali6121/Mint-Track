import 'package:flutter/material.dart';
import '../common/hive_storage.dart';
import '../models/setup_data.dart';

class CurrencyProvider with ChangeNotifier {
  String _currencySymbol = '₹'; // Default symbol
  String _currencyCode = 'INR'; // Default code

  String get currencySymbol => _currencySymbol;
  String get currencyCode => _currencyCode;

  CurrencyProvider() {
    loadCurrency();
  }

  /// Loads currency data from Hive and notifies listeners.
  Future<void> loadCurrency() async {
    final SetupData? setupData = HiveStorage.getSetupData();
    if (setupData != null) {
      _currencySymbol = setupData.currencySymbol;
      _currencyCode = setupData.currencyCode;

      // Notify all listening widgets that the data has changed.
      notifyListeners();
    }
  }

  /// Updates currency data and notifies listeners.
  void updateCurrency({
    required String newCode,
    required String newSymbol,
  }) {
    _currencyCode = newCode;
    _currencySymbol = newSymbol;
    notifyListeners();
  }
}