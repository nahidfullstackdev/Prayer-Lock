import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';

/// Repository interface for Qibla direction operations
abstract class QiblaRepository {
  /// Get Qibla direction from current location
  Future<Either<Failure, QiblaDirection>> getQiblaDirection(
    LocationData location,
  );
}
