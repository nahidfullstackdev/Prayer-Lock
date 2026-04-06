import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/location_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/models/location_data_model.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/location_repository.dart';

/// Implementation of LocationRepository with permission handling
class LocationRepositoryImpl implements LocationRepository {
  final LocationDataSource dataSource;
  final PrayerTimesLocalDataSource localDataSource;

  const LocationRepositoryImpl({
    required this.dataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, LocationData>> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await dataSource.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.warning('Location services are disabled');
        return const Left(
          PermissionFailure('Location services are disabled. Please enable them in settings.'),
        );
      }

      // Get current position
      final position = await dataSource.getCurrentPosition();

      // Reverse geocode to get city/country names
      final geoResult = await dataSource.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      // Create model with resolved names
      final locationModel = LocationDataModel(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: geoResult.cityName,
        countryName: geoResult.countryName,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final location = locationModel.toEntity();

      // Cache location for future use
      await localDataSource.saveLocation(locationModel);

      return Right(location);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting current location', e, stackTrace);
      return Left(UnknownFailure('Failed to get location: $e'));
    }
  }

  @override
  Future<Either<Failure, LocationData?>> getLastKnownLocation() async {
    try {
      final model = await localDataSource.getLastLocation();
      final location = model?.toEntity();
      return Right(location);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting last known location', e, stackTrace);
      return Left(CacheFailure('Failed to get last location: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveLocation(LocationData location) async {
    try {
      final model = LocationDataModel.fromEntity(location);
      await localDataSource.saveLocation(model);
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error saving location', e, stackTrace);
      return Left(CacheFailure('Failed to save location: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasLocationPermission() async {
    try {
      final permission = await dataSource.checkPermission();
      final hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      return Right(hasPermission);
    } catch (e, stackTrace) {
      AppLogger.error('Error checking location permission', e, stackTrace);
      return Left(UnknownFailure('Failed to check permission: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestLocationPermission() async {
    try {
      final permission = await dataSource.requestPermission();

      if (permission == LocationPermission.deniedForever) {
        AppLogger.warning('Location permission denied forever');
        return const Left(
          PermissionFailure(
            'Location permission denied permanently. Please enable it in app settings.',
          ),
        );
      }

      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (!granted) {
        AppLogger.warning('Location permission denied');
        return const Left(PermissionFailure('Location permission denied'));
      }

      return Right(granted);
    } catch (e, stackTrace) {
      AppLogger.error('Error requesting location permission', e, stackTrace);
      return Left(UnknownFailure('Failed to request permission: $e'));
    }
  }
}
