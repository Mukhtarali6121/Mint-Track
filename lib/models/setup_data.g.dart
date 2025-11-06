// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setup_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SetupDataAdapter extends TypeAdapter<SetupData> {
  @override
  final int typeId = 0;

  @override
  SetupData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SetupData(
      currencyCode: fields[0] as String,
      currencySymbol: fields[6] as String,
      country: fields[7] as String,
      financialGoal: fields[1] as String,
      expenseCategories: (fields[2] as List).cast<Category>(),
      incomeCategories: (fields[3] as List).cast<Category>(),
      timestamp: fields[4] as DateTime,
      userId: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SetupData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.currencyCode)
      ..writeByte(6)
      ..write(obj.currencySymbol)
      ..writeByte(7)
      ..write(obj.country)
      ..writeByte(1)
      ..write(obj.financialGoal)
      ..writeByte(2)
      ..write(obj.expenseCategories)
      ..writeByte(3)
      ..write(obj.incomeCategories)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetupDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
