import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';

/// Entity representing Qibla direction data for prayer
class QiblaDirection {
  /// Direction to Qibla in degrees from North (0-360)
  final double direction;

  /// Distance to the Kaaba in Makkah (kilometers)
  final double distance;

  /// Current location from which Qibla is calculated
  final LocationData currentLocation;

  const QiblaDirection({
    required this.direction,
    required this.distance,
    required this.currentLocation,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QiblaDirection &&
        other.direction == direction &&
        other.distance == distance &&
        other.currentLocation == currentLocation;
  }

  @override
  int get hashCode {
    return direction.hashCode ^ distance.hashCode ^ currentLocation.hashCode;
  }

  @override
  String toString() {
    return 'QiblaDirection(direction: ${direction.toStringAsFixed(1)}°, distance: ${distance.toStringAsFixed(1)}km)';
  }
}
