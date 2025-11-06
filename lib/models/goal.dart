import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'goal.g.dart';

enum GoalType {
  saving,
  spendingLimit,
}

// Hive adapter for GoalType enum
class GoalTypeAdapter extends TypeAdapter<GoalType> {
  @override
  final int typeId = 5;

  @override
  GoalType read(BinaryReader reader) {
    final index = reader.readByte();
    return GoalType.values[index];
  }

  @override
  void write(BinaryWriter writer, GoalType obj) {
    writer.writeByte(obj.index);
  }
}

@HiveType(typeId: 4)
class Goal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  GoalType type;

  @HiveField(3)
  double? targetAmount; // nullable for text-only goals

  @HiveField(4)
  double currentAmount; // calculated from transactions

  @HiveField(5)
  DateTime? deadline; // optional deadline

  @HiveField(6)
  String? categoryId; // optional category filter

  @HiveField(7)
  String? accountId; // optional account filter

  @HiveField(8)
  bool isCompleted;

  @HiveField(9)
  DateTime createdAt;

  @HiveField(10)
  String userId;

  @HiveField(11)
  bool isSynced; // Firestore sync status

  Goal({
    required this.id,
    required this.title,
    required this.type,
    this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    this.categoryId,
    this.accountId,
    this.isCompleted = false,
    required this.createdAt,
    required this.userId,
    this.isSynced = false,
  });

  // Convert from Firestore data
  factory Goal.fromFirestoreMap(Map<String, dynamic> data, String goalId) {
    return Goal(
      id: goalId,
      title: data['title'] as String? ?? '',
      type: _parseGoalType(data['type'] as String?),
      targetAmount: (data['targetAmount'] as num?)?.toDouble(),
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: data['deadline'] != null
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      categoryId: data['categoryId'] as String?,
      accountId: data['accountId'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      userId: data['userId'] as String? ?? '',
      isSynced: true, // Goals from Firestore are synced
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last, // 'saving' or 'spendingLimit'
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'categoryId': categoryId,
      'accountId': accountId,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
    };
  }

  Goal copyWith({
    String? id,
    String? title,
    GoalType? type,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    String? categoryId,
    String? accountId,
    bool? isCompleted,
    DateTime? createdAt,
    String? userId,
    bool? isSynced,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  // Calculate progress percentage (0-100)
  double get progressPercentage {
    if (targetAmount == null || targetAmount == 0) return 0.0;
    final percentage = (currentAmount / targetAmount!) * 100;
    return percentage.clamp(0.0, 100.0);
  }

  // Get remaining amount
  double? get remainingAmount {
    if (targetAmount == null) return null;
    return (targetAmount! - currentAmount).clamp(0.0, double.infinity);
  }

  // Helper to parse GoalType from string
  static GoalType _parseGoalType(String? typeString) {
    if (typeString == null) return GoalType.saving;
    if (typeString == 'saving') return GoalType.saving;
    if (typeString == 'spendingLimit') return GoalType.spendingLimit;
    return GoalType.saving; // default
  }
}

