import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';

part 'location_data_model.g.dart';

/// Hive model for caching location data
@HiveType(typeId: 2)
class LocationDataModel extends HiveObject {
  @HiveField(0)
  final double latitude;

  @HiveField(1)
  final double longitude;

  @HiveField(2)
  final String? cityName;

  @HiveField(3)
  final String? countryName;

  @HiveField(4)
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
