// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringTransactionAdapter extends TypeAdapter<RecurringTransaction> {
  @override
  final int typeId = 9;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: fields[2] as double,
      type: fields[3] as String,
      frequency: fields[4] as RecurringFrequency,
      startDate: fields[5] as DateTime,
      endDate: fields[6] as DateTime?,
      nextOccurrence: fields[7] as DateTime,
      category: fields[8] as String,
      accountId: fields[9] as String,
      isActive: fields[10] as bool,
      autoApprove: fields[11] as bool,
      lastProcessedDate: fields[12] as DateTime?,
      totalOccurrences: fields[13] as int,
      note: fields[14] as String?,
      createdAt: fields[15] as DateTime,
      userId: fields[16] as String,
      isSynced: fields[17] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.endDate)
      ..writeByte(7)
      ..write(obj.nextOccurrence)
      ..writeByte(8)
      ..write(obj.category)
      ..writeByte(9)
      ..write(obj.accountId)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.autoApprove)
      ..writeByte(12)
      ..write(obj.lastProcessedDate)
      ..writeByte(13)
      ..write(obj.totalOccurrences)
      ..writeByte(14)
      ..write(obj.note)
      ..writeByte(15)
      ..write(obj.createdAt)
      ..writeByte(16)
      ..write(obj.userId)
      ..writeByte(17)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
