import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';

/// Repository interface for location operations
abstract class LocationRepository {
  /// Get current GPS location
  /// Throws PermissionFailure if location permission is denied
  Future<Either<Failure, LocationData>> getCurrentLocation();

  /// Get last known location from cache
  /// Returns null if no cached location exists
  Future<Either<Failure, LocationData?>> getLastKnownLocation();

  /// Save location to cache
  Future<Either<Failure, void>> saveLocation(LocationData location);

  /// Check if app has location permissions
  Future<Either<Failure, bool>> hasLocationPermission();

  /// Request location permissions from user
  Future<Either<Failure, bool>> requestLocationPermission();
}
