import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'recurring_transaction.g.dart';

enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  quarterly,
  yearly,
}

// Hive adapter for RecurringFrequency enum
class RecurringFrequencyAdapter extends TypeAdapter<RecurringFrequency> {
  @override
  final int typeId = 8;

  @override
  RecurringFrequency read(BinaryReader reader) {
    final index = reader.readByte();
    return RecurringFrequency.values[index];
  }

  @override
  void write(BinaryWriter writer, RecurringFrequency obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 9)
class RecurringTransaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String type; // 'income' or 'expense'

  @HiveField(4)
  RecurringFrequency frequency;

  @HiveField(5)
  DateTime startDate;

  @HiveField(6)
  DateTime? endDate; // optional end date

  @HiveField(7)
  DateTime nextOccurrence;

  @HiveField(8)
  String category;

  @HiveField(9)
  String accountId;

  @HiveField(10)
  bool isActive;

  @HiveField(11)
  bool autoApprove; // if false, requires user approval

  @HiveField(12)
  DateTime? lastProcessedDate;

  @HiveField(13)
  int totalOccurrences; // count of how many times processed

  @HiveField(14)
  String? note;

  @HiveField(15)
  DateTime createdAt;

  @HiveField(16)
  String userId;

  @HiveField(17)
  bool isSynced; // Firestore sync status

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.nextOccurrence,
    required this.category,
    this.accountId = 'cash',
    this.isActive = true,
    this.autoApprove = false,
    this.lastProcessedDate,
    this.totalOccurrences = 0,
    this.note,
    required this.createdAt,
    required this.userId,
    this.isSynced = false,
  });

  // Convert from Firestore data
  factory RecurringTransaction.fromFirestoreMap(Map<String, dynamic> data, String recurringId) {
    return RecurringTransaction(
      id: recurringId,
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      type: data['type'] as String? ?? 'expense',
      frequency: _parseFrequency(data['frequency'] as String?),
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      nextOccurrence: data['nextOccurrence'] != null
          ? (data['nextOccurrence'] as Timestamp).toDate()
          : DateTime.now(),
      category: data['category'] as String? ?? 'Others',
      accountId: data['accountId'] as String? ?? 'cash',
      isActive: data['isActive'] as bool? ?? true,
      autoApprove: data['autoApprove'] as bool? ?? false,
      lastProcessedDate: data['lastProcessedDate'] != null
          ? (data['lastProcessedDate'] as Timestamp).toDate()
          : null,
      totalOccurrences: data['totalOccurrences'] as int? ?? 0,
      note: data['note'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] as String? ?? '',
      isSynced: true, // Recurring transactions from Firestore are synced
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'frequency': frequency.toString().split('.').last,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextOccurrence': Timestamp.fromDate(nextOccurrence),
      'category': category,
      'accountId': accountId,
      'isActive': isActive,
      'autoApprove': autoApprove,
      'lastProcessedDate': lastProcessedDate != null ? Timestamp.fromDate(lastProcessedDate!) : null,
      'totalOccurrences': totalOccurrences,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  RecurringTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextOccurrence,
    String? category,
    String? accountId,
    bool? isActive,
    bool? autoApprove,
    DateTime? lastProcessedDate,
    int? totalOccurrences,
    String? note,
    DateTime? createdAt,
    String? userId,
    bool? isSynced,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      isActive: isActive ?? this.isActive,
      autoApprove: autoApprove ?? this.autoApprove,
      lastProcessedDate: lastProcessedDate ?? this.lastProcessedDate,
      totalOccurrences: totalOccurrences ?? this.totalOccurrences,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Helper to parse RecurringFrequency from string
  static RecurringFrequency _parseFrequency(String? frequencyString) {
    if (frequencyString == null) return RecurringFrequency.monthly;
    switch (frequencyString) {
      case 'daily':
        return RecurringFrequency.daily;
      case 'weekly':
        return RecurringFrequency.weekly;
      case 'monthly':
        return RecurringFrequency.monthly;
      case 'quarterly':
        return RecurringFrequency.quarterly;
      case 'yearly':
        return RecurringFrequency.yearly;
      default:
        return RecurringFrequency.monthly;
    }
  }

  // Calculate next occurrence date based on frequency
  DateTime calculateNextOccurrence(DateTime fromDate) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return fromDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return fromDate.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
      case RecurringFrequency.quarterly:
        return DateTime(fromDate.year, fromDate.month + 3, fromDate.day);
      case RecurringFrequency.yearly:
        return DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
    }
  }

  // Check if recurring transaction is due (nextOccurrence <= today)
  bool get isDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDate = DateTime(nextOccurrence.year, nextOccurrence.month, nextOccurrence.day);
    return nextDate.isBefore(today) || nextDate.isAtSameMomentAs(today);
  }

  // Check if recurring transaction has ended
  bool get hasEnded {
    if (endDate == null) return false;
    final now = DateTime.now();
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return end.isBefore(today);
  }
}

