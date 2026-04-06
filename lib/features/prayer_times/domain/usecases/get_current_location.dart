import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/location_repository.dart';

/// Use case for getting current GPS location with permission handling
class GetCurrentLocationUseCase {
  final LocationRepository repository;

  const GetCurrentLocationUseCase({required this.repository});

  Future<Either<Failure, LocationData>> call() async {
    // Check if location permission is granted
    final hasPermissionResult = await repository.hasLocationPermission();

    return await hasPermissionResult.fold(
      (failure) => Left(failure),
      (hasPermission) async {
        if (!hasPermission) {
          // Request permission if not granted
          final requestResult = await repository.requestLocationPermission();

          return await requestResult.fold(
            (failure) => Left(failure),
            (granted) async {
              if (granted) {
                return await repository.getCurrentLocation();
              } else {
                return const Left(
                  PermissionFailure('Location permission denied by user'),
                );
              }
            },
          );
        }

        // Permission already granted, fetch location
        return await repository.getCurrentLocation();
      },
    );
  }
}
