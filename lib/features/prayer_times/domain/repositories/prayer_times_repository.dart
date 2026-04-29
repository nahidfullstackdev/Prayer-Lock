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

  /// Emits a date key (`yyyy-MM-dd`) whenever a stale-while-revalidate
  /// background refresh has just written fresh data into the cache for
  /// that date. UI layers (e.g. the prayer-times notifier) listen here
  /// to silently re-derive their state without showing a loading spinner.
  Stream<String> get cacheUpdates;

  /// Releases stream resources. Safe to call multiple times. Wired via
  /// `ref.onDispose` in the Riverpod provider so hot-restarts do not leak
  /// the underlying `StreamController`.
  Future<void> dispose();
}
