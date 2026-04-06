import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';

/// Model for Qibla direction data
class QiblaDirectionModel {
  final double direction;
  final double distance;
  final LocationData currentLocation;

  const QiblaDirectionModel({
    required this.direction,
    required this.distance,
    required this.currentLocation,
  });

  /// Create from domain entity
  factory QiblaDirectionModel.fromEntity(QiblaDirection entity) {
    return QiblaDirectionModel(
      direction: entity.direction,
      distance: entity.distance,
      currentLocation: entity.currentLocation,
    );
  }

  /// Convert to domain entity
  QiblaDirection toEntity() {
    return QiblaDirection(
      direction: direction,
      distance: distance,
      currentLocation: currentLocation,
    );
  }
}
