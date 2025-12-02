// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_contribution.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoalContributionAdapter extends TypeAdapter<GoalContribution> {
  @override
  final int typeId = 10;

  @override
  GoalContribution read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoalContribution(
      id: fields[0] as String,
      goalId: fields[1] as String,
      amount: fields[2] as double,
      transactionId: fields[3] as String,
      date: fields[4] as DateTime,
      createdAt: fields[5] as DateTime,
      userId: fields[6] as String,
      isSynced: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GoalContribution obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.transactionId)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.userId)
      ..writeByte(7)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalContributionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
