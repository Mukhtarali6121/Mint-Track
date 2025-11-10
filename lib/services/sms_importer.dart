import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class SmsImporter {
  SmsImporter(this._query);

  final SmsQuery _query;
  static const String _reviewedKey = 'reviewed_sms_ids_v1';

  Future<bool> ensurePermissions() async {
    var status = await Permission.sms.status;
    if (status.isGranted) return true;
    status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<Set<String>> _loadReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_reviewedKey)?.toSet() ?? <String>{};
  }

  Future<void> _saveReviewed(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_reviewedKey, ids.toList());
  }

  Future<List<SmsMessage>> fetchLastTwoDaysUnreviewed() async {
    final reviewed = await _loadReviewed();
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 2));
    final msgs = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 200,
    );
    final recent = msgs.where((m) => m.date != null && m.date!.isAfter(from)).toList();
    return recent.where((m) => m.id != null && !reviewed.contains(m.id.toString())).toList();
  }

  Future<List<SmsMessage>> fetchUnreviewedInRange({required DateTime start, required DateTime end}) async {
    final reviewed = await _loadReviewed();
    final msgs = await _query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 500,
    );
    final inRange = msgs.where((m) {
      final d = m.date;
      if (d == null) return false;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
    return inRange.where((m) => m.id != null && !reviewed.contains(m.id.toString())).toList();
  }

  // Very simple parser for common bank/SMS formats. Extend as needed.
  ParsedSms? parseToTransaction(String body, DateTime receivedAt) {
    final lower = body.toLowerCase();
    final expenseKeywords = ['debited', 'spent', 'purchase', 'withdrawn'];
    final incomeKeywords = ['credited', 'received'];
    TransactionType? type;
    if (expenseKeywords.any(lower.contains)) type = TransactionType.expense;
    if (incomeKeywords.any(lower.contains)) type = TransactionType.income;
    if (type == null) return null;

    // Match amount
    final amountRegex = RegExp(
      r'(?:debited|credited|spent|received)\s*(?:by)?\s*(?:inr|rs|rs\.|₹)?\s*([0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );
    final match = amountRegex.firstMatch(body);
    if (match == null) return null;
    final amt = double.tryParse(match.group(1)!);  // <-- use group(1)
    if (amt == null) return null;

    // Extract merchant/source name
    String title = type == TransactionType.expense ? 'Card spending' : 'Account credit';
    final merchantMatch = RegExp(r'trf to\s+([A-Za-z0-9 &._-]{3,})', caseSensitive: false).firstMatch(body);
    if (merchantMatch != null) {
      title = merchantMatch.group(1)!.trim();
    }

    return ParsedSms(title: title, amount: amt, type: type, date: receivedAt);
  }


  Future<void> markReviewed(Iterable<SmsMessage> messages) async {
    final reviewed = await _loadReviewed();
    for (final m in messages) {
      final id = m.id?.toString();
      if (id != null) reviewed.add(id);
    }
    await _saveReviewed(reviewed);
  }
}

@immutable
class ParsedSms {
  const ParsedSms({
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
  });

  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
}

