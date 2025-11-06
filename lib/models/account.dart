import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'account.g.dart';

@HiveType(typeId: 3)
class Account extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double balance;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  String userId;

  @HiveField(5)
  bool isSynced; // Track if synced to Firestore

  Account({
    required this.id,
    required this.name,
    this.balance = 0.0,
    required this.createdAt,
    required this.userId,
    this.isSynced = false,
  });

  // Convert from Firestore data
  factory Account.fromFirestoreMap(Map<String, dynamic> data, String accountId) {
    return Account(
      id: accountId,
      name: data['name'] as String? ?? '',
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] as String? ?? '',
      isSynced: true, // Accounts from Firestore are synced
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'isSynced': isSynced,
    };
  }

  Account copyWith({
    String? id,
    String? name,
    double? balance,
    DateTime? createdAt,
    String? userId,
    bool? isSynced,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

