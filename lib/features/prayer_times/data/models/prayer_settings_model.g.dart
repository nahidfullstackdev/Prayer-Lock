// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prayer_settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PrayerSettingsModelAdapter extends TypeAdapter<PrayerSettingsModel> {
  @override
  final int typeId = 1;

  @override
  PrayerSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerSettingsModel(
      calculationMethod: fields[0] as int,
      madhab: fields[1] as int,
      notificationsEnabled: (fields[2] as Map).cast<String, bool>(),
      notificationMinutesBefore: fields[3] as int,
      // Field 4 may be absent in records written before adhanType was added.
      // Falling back to 0 (AdhanType.standard) keeps existing users on adhan.
      adhanTypeIndex: fields[4] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerSettingsModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.calculationMethod)
      ..writeByte(1)
      ..write(obj.madhab)
      ..writeByte(2)
      ..write(obj.notificationsEnabled)
      ..writeByte(3)
      ..write(obj.notificationMinutesBefore)
      ..writeByte(4)
      ..write(obj.adhanTypeIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
