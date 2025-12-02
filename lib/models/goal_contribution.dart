import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'goal_contribution.g.dart';

@HiveType(typeId: 10)
class GoalContribution extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String goalId; // ID of the goal this contribution is for

  @HiveField(2)
  double amount; // Amount contributed

  @HiveField(3)
  String transactionId; // ID of the income transaction that was contributed

  @HiveField(4)
  DateTime date; // Date of contribution

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  String userId;

  @HiveField(7)
  bool isSynced; // Firestore sync status

  GoalContribution({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.transactionId,
    required this.date,
    required this.createdAt,
    required this.userId,
    this.isSynced = false,
  });

  // Convert from Firestore data
  factory GoalContribution.fromFirestoreMap(Map<String, dynamic> data, String contributionId) {
    return GoalContribution(
      id: contributionId,
      goalId: data['goalId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      transactionId: data['transactionId'] as String? ?? '',
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] as String? ?? '',
      isSynced: true, // Contributions from Firestore are synced
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'transactionId': transactionId,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  GoalContribution copyWith({
    String? id,
    String? goalId,
    double? amount,
    String? transactionId,
    DateTime? date,
    DateTime? createdAt,
    String? userId,
    bool? isSynced,
  }) {
    return GoalContribution(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      transactionId: transactionId ?? this.transactionId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

