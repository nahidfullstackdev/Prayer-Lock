import 'package:geolocator/geolocator.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/domain/utils/qibla_math.dart';

/// Data source for Qibla direction.
///
/// Computes the Qibla bearing mathematically from the user's coordinates
/// using the great-circle initial bearing formula. The compass-heading
/// stream is supplied separately by the UI layer via `flutter_qiblah`.
class QiblaDataSource {
  /// Computes the absolute Qibla bearing (from true north) and the
  /// distance to the Kaaba for the given location.
  Future<QiblaDirection> getQiblaDirection(LocationData location) async {
    try {
      final bearing = QiblaMath.calculateQiblaBearing(
        location.latitude,
        location.longitude,
      );
      final distance = _calculateDistanceToKaaba(
        location.latitude,
        location.longitude,
      );

      AppLogger.info(
        'Qibla bearing: ${bearing.toStringAsFixed(1)}°, '
        'distance: ${distance.toStringAsFixed(1)}km',
      );

      return QiblaDirection(
        direction: bearing,
        distance: distance,
        currentLocation: location,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error calculating Qibla direction', e, stackTrace);
      rethrow;
    }
  }

  double _calculateDistanceToKaaba(double latitude, double longitude) {
    return Geolocator.distanceBetween(
          latitude,
          longitude,
          QiblaMath.kaabaLatitude,
          QiblaMath.kaabaLongitude,
        ) /
        1000;
  }
}
