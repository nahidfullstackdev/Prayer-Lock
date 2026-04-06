// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_data_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocationDataModelAdapter extends TypeAdapter<LocationDataModel> {
  @override
  final int typeId = 2;

  @override
  LocationDataModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocationDataModel(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      cityName: fields[2] as String?,
      countryName: fields[3] as String?,
      timestamp: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, LocationDataModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.cityName)
      ..writeByte(3)
      ..write(obj.countryName)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationDataModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
