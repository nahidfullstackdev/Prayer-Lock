import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';

/// Data source for Qibla direction using flutter_qiblah package
class QiblaDataSource {
  /// Kaaba coordinates in Makkah
  static const double kaabaLatitude = 21.4225;
  static const double kaabaLongitude = 39.8262;

  /// Get Qibla direction from current location
  Future<QiblaDirection> getQiblaDirection(LocationData location) async {
    try {
      AppLogger.info('Calculating Qibla direction');

      // Get first value from Qibla stream
      final qibla = await FlutterQiblah.qiblahStream.first;

      // Calculate distance to Kaaba
      final distance = _calculateDistanceToKaaba(
        location.latitude,
        location.longitude,
      );

      AppLogger.info(
        'Qibla: ${qibla.direction.toStringAsFixed(1)}°, Distance: ${distance.toStringAsFixed(1)}km',
      );

      return QiblaDirection(
        direction: qibla.direction,
        distance: distance,
        currentLocation: location,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error calculating Qibla direction', e, stackTrace);
      rethrow;
    }
  }

  /// Stream of compass heading updates for live compass
  Stream<double> getCompassHeadingStream() {
    try {
      AppLogger.info('Starting Qibla compass stream');
      return FlutterQiblah.qiblahStream.map((event) => event.direction);
    } catch (e, stackTrace) {
      AppLogger.error('Error starting compass stream', e, stackTrace);
      rethrow;
    }
  }

  /// Calculate distance from given coordinates to Kaaba using Haversine formula
  double _calculateDistanceToKaaba(double latitude, double longitude) {
    return Geolocator.distanceBetween(
          latitude,
          longitude,
          kaabaLatitude,
          kaabaLongitude,
        ) /
        1000; // Convert meters to kilometers
  }
}
