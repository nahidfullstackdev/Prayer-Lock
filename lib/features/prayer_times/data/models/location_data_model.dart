import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';

/// Hive model for caching location data.
/// Adapter is hand-written below — typeId 2, field layout must stay
/// identical to the previously generated adapter so existing user
/// data on disk keeps decoding.
class LocationDataModel extends HiveObject {
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? countryName;
  final int timestamp; // Unix timestamp in milliseconds

  LocationDataModel({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.countryName,
    required this.timestamp,
  });

  /// Create model from domain entity
  factory LocationDataModel.fromEntity(LocationData entity) {
    return LocationDataModel(
      latitude: entity.latitude,
      longitude: entity.longitude,
      cityName: entity.cityName,
      countryName: entity.countryName,
      timestamp: entity.timestamp.millisecondsSinceEpoch,
    );
  }

  /// Create model from Geolocator Position
  factory LocationDataModel.fromPosition(Position position) {
    return LocationDataModel(
      latitude: position.latitude,
      longitude: position.longitude,
      cityName: null,
      countryName: null,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Convert model to domain entity
  LocationData toEntity() {
    return LocationData(
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      countryName: countryName,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }
}

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
