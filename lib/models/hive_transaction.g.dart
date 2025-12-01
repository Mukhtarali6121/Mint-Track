// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveTransactionAdapter extends TypeAdapter<HiveTransaction> {
  @override
  final int typeId = 1;

  @override
  HiveTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as String,
      date: fields[4] as DateTime,
      category: fields[5] as String,
      note: fields[6] as String?,
      isSynced: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      userId: fields[9] as String,
      accountId: fields[10] as String,
      recurringTransactionId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveTransaction obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.isSynced)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.accountId)
      ..writeByte(11)
      ..write(obj.recurringTransactionId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
