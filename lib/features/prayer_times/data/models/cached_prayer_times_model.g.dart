// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_prayer_times_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedPrayerTimesModelAdapter
    extends TypeAdapter<CachedPrayerTimesModel> {
  @override
  final int typeId = 0;

  @override
  CachedPrayerTimesModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedPrayerTimesModel(
      dateKey: fields[0] as String,
      fajrTime: fields[1] as String,
      dhuhrTime: fields[2] as String,
      asrTime: fields[3] as String,
      maghribTime: fields[4] as String,
      ishaTime: fields[5] as String,
      latitude: fields[6] as double,
      longitude: fields[7] as double,
      calculationMethod: fields[8] as int,
      madhab: fields[9] as int,
      cachedAt: fields[10] as int,
      cityName: fields[11] as String?,
      countryName: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedPrayerTimesModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.fajrTime)
      ..writeByte(2)
      ..write(obj.dhuhrTime)
      ..writeByte(3)
      ..write(obj.asrTime)
      ..writeByte(4)
      ..write(obj.maghribTime)
      ..writeByte(5)
      ..write(obj.ishaTime)
      ..writeByte(6)
      ..write(obj.latitude)
      ..writeByte(7)
      ..write(obj.longitude)
      ..writeByte(8)
      ..write(obj.calculationMethod)
      ..writeByte(9)
      ..write(obj.madhab)
      ..writeByte(10)
      ..write(obj.cachedAt)
      ..writeByte(11)
      ..write(obj.cityName)
      ..writeByte(12)
      ..write(obj.countryName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedPrayerTimesModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
