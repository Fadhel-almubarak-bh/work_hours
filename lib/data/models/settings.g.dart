// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 2;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      monthlySalary: fields[0] as double,
      dailyTargetHours: fields[1] as int,
      workDays: (fields[2] as List).cast<bool>(),
      currency: fields[3] as String,
      insuranceRate: fields[4] as double,
      overtimeRate: fields[5] as double,
      themeMode: fields[6] as ThemeMode,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.monthlySalary)
      ..writeByte(1)
      ..write(obj.dailyTargetHours)
      ..writeByte(2)
      ..write(obj.workDays)
      ..writeByte(3)
      ..write(obj.currency)
      ..writeByte(4)
      ..write(obj.insuranceRate)
      ..writeByte(5)
      ..write(obj.overtimeRate)
      ..writeByte(6)
      ..write(obj.themeMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
