import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'hive_transaction.g.dart';

@HiveType(typeId: 1)
class HiveTransaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String type; // 'income' or 'expense'

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String category;

  @HiveField(6)
  String? note;

  @HiveField(7)
  bool isSynced; // Track if synced to Firestore

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  String userId;

  @HiveField(10)
  String accountId;

  @HiveField(11)
  String? recurringTransactionId; // ID of the recurring transaction that created this

  HiveTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.note,
    this.isSynced = false,
    required this.createdAt,
    required this.userId,
    this.accountId = 'cash',
    this.recurringTransactionId,
  });

  // Convert from TransactionItem to HiveTransaction
  factory HiveTransaction.fromTransactionItem(Map<String, dynamic> data, String userId) {
    return HiveTransaction(
      id: data['id'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      type: data['type'] as String,
      date: (data['date'] as Timestamp).toDate(),
      category: data['category'] as String,
      note: data['note'] as String?,
      isSynced: data['isSynced'] as bool? ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      userId: userId,
      accountId: data['accountId'] as String? ?? 'cash',
      recurringTransactionId: data['recurringTransactionId'] as String?,
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': Timestamp.fromDate(date),
      'category': category,
      'note': note,
      'isSynced': isSynced,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'accountId': accountId,
      'recurringTransactionId': recurringTransactionId,
    };
  }

  // Convert to TransactionItem format for UI
  Map<String, dynamic> toTransactionItemMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'category': category,
      'note': note,
      'accountId': accountId,
      'recurringTransactionId': recurringTransactionId,
    };
  }

  // Create from TransactionItem
  factory HiveTransaction.fromTransactionItemData(Map<String, dynamic> data, String userId) {
    return HiveTransaction(
      id: data['id'] as String,
      title: data['title'] as String,
      amount: (data['amount'] as num).toDouble(),
      type: data['type'] as String,
      date: DateTime.parse(data['date'] as String),
      category: data['category'] as String,
      note: data['note'] as String?,
      isSynced: false, // New transactions are not synced initially
      createdAt: DateTime.now(),
      userId: userId,
      accountId: data['accountId'] as String? ?? 'cash',
      recurringTransactionId: data['recurringTransactionId'] as String?,
    );
  }

  HiveTransaction copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    DateTime? date,
    String? category,
    String? note,
    bool? isSynced,
    DateTime? createdAt,
    String? userId,
    String? accountId,
    String? recurringTransactionId,
  }) {
    return HiveTransaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      recurringTransactionId: recurringTransactionId ?? this.recurringTransactionId,
    );
  }
}
