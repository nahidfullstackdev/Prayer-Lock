import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// Data source for location operations using Geolocator and Geocoding
class LocationDataSource {
  /// Get current GPS position
  Future<Position> getCurrentPosition() async {
    try {
      AppLogger.info('Requesting current GPS location');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      AppLogger.info(
        'Location obtained: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting current location', e, stackTrace);
      rethrow;
    }
  }

  /// Reverse geocode coordinates to get city and country names
  Future<({String? cityName, String? countryName})> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      AppLogger.info('Reverse geocoding: $latitude, $longitude');

      final placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city =
            place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea;
        final country = place.country;

        AppLogger.info('Resolved location: $city, $country');
        return (cityName: city, countryName: country);
      }

      AppLogger.warning('No placemarks found for coordinates');
      return (cityName: null, countryName: null);
    } catch (e) {
      AppLogger.warning('Reverse geocoding failed: $e');
      return (cityName: null, countryName: null);
    }
  }

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    AppLogger.info('Location services enabled: $enabled');
    return enabled;
  }

  /// Check current location permission status
  Future<LocationPermission> checkPermission() async {
    final permission = await Geolocator.checkPermission();
    AppLogger.info('Location permission status: $permission');
    return permission;
  }

  /// Request location permission from user
  Future<LocationPermission> requestPermission() async {
    AppLogger.info('Requesting location permission');
    final permission = await Geolocator.requestPermission();
    AppLogger.info('Permission result: $permission');
    return permission;
  }
}
