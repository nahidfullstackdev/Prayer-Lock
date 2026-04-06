import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/location_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// Use case for getting prayer times for a specific date and location
class GetPrayerTimesUseCase {
  final PrayerTimesRepository prayerTimesRepository;
  final LocationRepository locationRepository;

  const GetPrayerTimesUseCase({
    required this.prayerTimesRepository,
    required this.locationRepository,
  });

  /// Get prayer times for today or a specific date
  /// If location is not provided, fetches current GPS location
  /// If date is not provided, uses today's date
  Future<Either<Failure, PrayerTimes>> call({
    LocationData? location,
    DateTime? date,
  }) async {
    // Use today's date if not provided
    final targetDate = date ?? DateTime.now();

    // Get location if not provided
    final Either<Failure, LocationData> locationResult;
    if (location != null) {
      locationResult = Right(location);
    } else {
      locationResult = await locationRepository.getCurrentLocation();
    }

    // Return early if location fetch failed
    return await locationResult.fold(
      (failure) => Left(failure),
      (locationData) async {
        // Get settings
        final settingsResult = await prayerTimesRepository.getSettings();

        return await settingsResult.fold(
          (failure) => Left(failure),
          (settings) async {
            // Fetch prayer times with location and settings
            return await prayerTimesRepository.getPrayerTimes(
              date: targetDate,
              location: locationData,
              settings: settings,
            );
          },
        );
      },
    );
  }
}
