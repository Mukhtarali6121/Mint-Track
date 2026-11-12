import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models.dart';

/// Model representing a transaction parsed from a bank SMS
class DetectedTransaction {
  final double amount;
  final TransactionType type;
  final String bank;
  final String title;
  final String account;
  final DateTime timestamp;
  final String smsBody;

  const DetectedTransaction({
    required this.amount,
    required this.type,
    required this.bank,
    required this.title,
    required this.account,
    required this.timestamp,
    required this.smsBody,
  });

  factory DetectedTransaction.fromMap(Map<dynamic, dynamic> map) {
    final rawAmount = map['amount'];
    final double amount = (rawAmount is num) ? rawAmount.toDouble() : 0.0;
    final String rawType = (map['type'] ?? 'expense').toString().toLowerCase();
    final TransactionType type = rawType == 'income' ? TransactionType.income : TransactionType.expense;
    final int rawTs = (map['timestamp'] is num) ? (map['timestamp'] as num).toInt() : DateTime.now().millisecondsSinceEpoch;

    return DetectedTransaction(
      amount: amount,
      type: type,
      bank: (map['bank'] ?? 'Bank').toString(),
      title: (map['title'] ?? '').toString(),
      account: (map['account'] ?? '').toString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(rawTs),
      smsBody: (map['sms_body'] ?? '').toString(),
    );
  }
}

class SmsTransactionService {
  static final SmsTransactionService _instance = SmsTransactionService._internal();
  factory SmsTransactionService() => _instance;
  SmsTransactionService._internal();

  static const MethodChannel _channel = MethodChannel('com.expense.tracker/sms_transaction');

  final StreamController<DetectedTransaction> _controller = StreamController<DetectedTransaction>.broadcast();
  Stream<DetectedTransaction> get onTransactionDetected => _controller.stream;

  bool _isInitialized = false;

  /// Initialize channel to listen for background transaction intents
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        debugPrint('SmsTransactionService method call: ${call.method}');
        if (call.method == 'onTransactionDetected') {
          if (call.arguments is Map) {
            final txn = DetectedTransaction.fromMap(call.arguments as Map);
            _controller.add(txn);
          }
        }
      });
    }
  }

  /// Retrieve any pending transaction captured before Flutter loaded
  Future<DetectedTransaction?> checkPendingTransaction() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final result = await _channel.invokeMethod('getPendingTransaction');
      if (result is Map) {
        final txn = DetectedTransaction.fromMap(result);
        _controller.add(txn);
        return txn;
      }
    } catch (e) {
      debugPrint('Error getting pending transaction: $e');
    }
    return null;
  }

  /// Request SMS permissions from the user
  Future<bool> requestSmsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Check whether SMS permission is granted
  Future<bool> hasSmsPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    return await Permission.sms.isGranted;
  }

  /// Helper for development/testing: Simulate an incoming bank transaction
  void simulateTestTransaction({
    double amount = 450.0,
    TransactionType type = TransactionType.expense,
    String bank = 'HDFC Bank',
    String title = 'Starbucks Coffee',
    String account = '1234',
  }) {
    _controller.add(
      DetectedTransaction(
        amount: amount,
        type: type,
        bank: bank,
        title: title,
        account: account,
        timestamp: DateTime.now(),
        smsBody: 'Test transaction simulated',
      ),
    );
  }

  void dispose() {
    _controller.close();
  }
}
