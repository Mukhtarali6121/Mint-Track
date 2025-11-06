// lib/common/formatter.dart
import 'package:intl/intl.dart';

import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format({
    required double amount,
    required String symbol,
    int decimalDigits = 2,
    bool spaceBetween = false,
  }) {
    final formattedNumber = NumberFormat.currency(
      symbol: '', // We'll manually prepend symbol for space control
      decimalDigits: decimalDigits,
    ).format(amount);

    return spaceBetween ? '$symbol $formattedNumber' : '$symbol$formattedNumber';
  }
}
