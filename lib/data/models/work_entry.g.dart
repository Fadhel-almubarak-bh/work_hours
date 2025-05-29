// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkEntryAdapter extends TypeAdapter<WorkEntry> {
  @override
  final int typeId = 1;

  @override
  WorkEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkEntry(
      date: fields[0] as DateTime,
      clockIn: fields[1] as DateTime?,
      clockOut: fields[2] as DateTime?,
      duration: fields[3] as int,
      isOffDay: fields[4] as bool,
      description: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WorkEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.clockIn)
      ..writeByte(2)
      ..write(obj.clockOut)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.isOffDay)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
