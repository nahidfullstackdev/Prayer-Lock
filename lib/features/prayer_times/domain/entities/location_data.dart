import 'dart:math';

/// Entity representing geographical location data
class LocationData {
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? countryName;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.countryName,
    required this.timestamp,
  });

  /// Checks if this location is significantly different from another location
  /// Returns true if distance is greater than 10 kilometers
  bool isDifferentFrom(LocationData other) {
    const double significantDistanceKm = 10.0;
    final distance = _calculateDistanceInKm(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
    return distance > significantDistanceKm;
  }

  /// Calculates distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  double _calculateDistanceInKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusKm = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LocationData &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.cityName == cityName &&
        other.countryName == countryName &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        cityName.hashCode ^
        countryName.hashCode ^
        timestamp.hashCode;
  }

  @override
  String toString() {
    return 'LocationData(lat: $latitude, lon: $longitude, city: $cityName, country: $countryName)';
  }
}
