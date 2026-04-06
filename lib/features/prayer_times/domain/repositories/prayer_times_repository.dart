import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Repository interface for prayer times operations
abstract class PrayerTimesRepository {
  /// Get prayer times for a specific date and location
  /// Implements offline-first: Check cache first, fallback to API
  Future<Either<Failure, PrayerTimes>> getPrayerTimes({
    required DateTime date,
    required LocationData location,
    required PrayerSettings settings,
  });

  /// Get prayer settings from local storage
  Future<Either<Failure, PrayerSettings>> getSettings();

  /// Update prayer settings in local storage
  Future<Either<Failure, void>> updateSettings(PrayerSettings settings);

  /// Clear cached prayer times (for manual refresh or testing)
  Future<Either<Failure, void>> clearCache();
}
