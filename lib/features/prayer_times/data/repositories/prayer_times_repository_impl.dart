import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/network/connectivity_service.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_remote_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/models/cached_prayer_times_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/prayer_settings_model.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// Offline-first prayer-times repository.
///
/// Decision flow for [getPrayerTimes]:
///
///   1. Cache fresh & exact          → return immediately. If older than the
///                                     soft TTL, also fire a silent
///                                     stale-while-revalidate refresh.
///   2. Cache invalid / missing,     → hit Aladhan. On success, cache and
///      device online                  return. On failure, fall through to (3).
///   3. Offline OR network failed    → resolve via the local data source's
///                                     3-tier fallback (exact → same-month →
///                                     globally latest). Return whatever
///                                     comes back so the UI is never blank.
///                                     If online, schedule a background
///                                     refresh so the next open is fresh.
///   4. No cache anywhere            → only now do we surface a Failure.
///
/// On every successful read for [date], tomorrow's cache is pre-warmed in
/// the background (if missing/invalid and the device is online). This keeps
/// "today" always available the moment the calendar rolls over, even if the
/// user opens the app offline at 12:01am.
class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remoteDataSource;
  final PrayerTimesLocalDataSource localDataSource;
  final ConnectivityService connectivity;

  /// Past this age, a *valid* cache entry triggers a background refresh while
  /// still being returned immediately. One hour catches externally-changed
  /// settings and pre-warms tomorrow's data without hammering the API.
  static const int _kSoftTtlSeconds = 60 * 60;

  final StreamController<String> _cacheUpdatesController =
      StreamController<String>.broadcast();

  /// In-flight background fetches, keyed by dateKey. Prevents duplicate
  /// network calls when the user opens the app rapidly or when SWR overlaps
  /// with a tomorrow pre-warm for the same date.
  final Set<String> _inFlightRefreshes = <String>{};

  PrayerTimesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.connectivity,
  });

  @override
  Stream<String> get cacheUpdates => _cacheUpdatesController.stream;

  @override
  Future<Either<Failure, PrayerTimes>> getPrayerTimes({
    required DateTime date,
    required LocationData location,
    required PrayerSettings settings,
  }) async {
    try {
      final dateKey = _formatDateKey(date);
      final exact = localDataSource.getCachedPrayerTimes(dateKey);
      final invalidReason =
          exact?.invalidationReason(date, location, settings);

      // ── (1) Exact cache fresh → return now. SWR may fire in background.
      if (exact != null && invalidReason == null) {
        _maybeBackgroundRefresh(dateKey, exact, date, location, settings);
        _maybePrewarmNextDay(date, location, settings);
        return Right(exact.toEntity(settings.notificationsEnabled));
      }

      if (exact != null) {
        AppLogger.info('Cache invalid for $dateKey: $invalidReason');
      } else {
        AppLogger.info('No exact cache for $dateKey');
      }

      // ── (2) Online: try the network. On success, cache and return.
      final online = await connectivity.isOnline();
      if (online) {
        AppLogger.info('Fetching from Aladhan API for $dateKey');
        final fetchResult = await _fetchAndCache(date, location, settings);
        if (fetchResult.isRight()) {
          _maybePrewarmNextDay(date, location, settings);
          return fetchResult;
        }
        AppLogger.warning(
          'Network fetch failed for $dateKey — falling through to cache',
        );
      } else {
        AppLogger.warning('Offline — skipping network for $dateKey');
      }

      // ── (3) Offline or fetch failed → 3-tier intelligent fallback.
      final fallback = localDataSource.resolveCachedPrayerTimes(
        dateKey: dateKey,
        date: date,
      );
      if (fallback != null) {
        if (fallback.dateKey != dateKey) {
          AppLogger.warning(
            'Returning fallback cache (${fallback.dateKey}) '
            'for requested $dateKey',
          );
        }
        // Online but the fetch just failed (captive portal, transient 5xx) —
        // queue a background retry so the next open has fresh data.
        if (online) {
          _scheduleBackgroundRefresh(dateKey, date, location, settings);
        }
        return Right(fallback.toEntity(settings.notificationsEnabled));
      }

      // ── (4) Cache truly empty. Only now do we fail.
      if (!online) {
        return const Left(
          NetworkFailure(
            'No internet connection and no cached prayer times available.',
          ),
        );
      }
      return const Left(
        ServerFailure(
          'Failed to load prayer times. Please try again.',
        ),
      );
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching prayer times', e, stackTrace);
      return Left(UnknownFailure('Failed to load prayer times: $e'));
    }
  }

  @override
  Future<Either<Failure, PrayerSettings>> getSettings() async {
    try {
      final model = localDataSource.getSettings();
      return Right(model.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('Error getting prayer settings', e, stackTrace);
      return Left(CacheFailure('Failed to load settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSettings(PrayerSettings settings) async {
    try {
      final model = PrayerSettingsModel.fromEntity(settings);
      await localDataSource.saveSettings(model);
      AppLogger.info('Prayer settings updated successfully');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating prayer settings', e, stackTrace);
      return Left(CacheFailure('Failed to save settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      await localDataSource.clearPrayerTimesCache();
      AppLogger.info('Prayer times cache cleared');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing cache', e, stackTrace);
      return Left(CacheFailure('Failed to clear cache: $e'));
    }
  }

  @override
  Future<void> dispose() async {
    if (!_cacheUpdatesController.isClosed) {
      await _cacheUpdatesController.close();
    }
  }

  // ── private ─────────────────────────────────────────────────────────────────

  /// Network fetch + cache write. Returns Either so callers can decide what
  /// to do on failure (the outer flow falls back to the 3-tier cache lookup).
  Future<Either<Failure, PrayerTimes>> _fetchAndCache(
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) async {
    try {
      final response = await remoteDataSource.fetchPrayerTimes(
        date: date,
        latitude: location.latitude,
        longitude: location.longitude,
        method: settings.calculationMethod,
        school: settings.madhab,
      );
      final cacheModel = CachedPrayerTimesModel.fromApiResponse(
        response,
        location,
        settings,
      );
      await localDataSource.cachePrayerTimes(cacheModel);
      return Right(cacheModel.toEntity(settings.notificationsEnabled));
    } on DioException catch (e) {
      AppLogger.error('Network error fetching prayer times', e);
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const Left(
          NetworkFailure(
            'No internet connection. Please check your network.',
          ),
        );
      }
      if (e.response?.statusCode != null) {
        return Left(
          ServerFailure(
            'Server error (${e.response!.statusCode}). '
            'Please try again later.',
          ),
        );
      }
      return Left(ServerFailure(e.message ?? 'Failed to fetch prayer times'));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected fetch error', e, stackTrace);
      return Left(UnknownFailure('Failed to fetch prayer times: $e'));
    }
  }

  /// Stale-while-revalidate: if the cache is older than the soft TTL and no
  /// other refresh is in flight for the same date, kick off a silent fetch.
  void _maybeBackgroundRefresh(
    String dateKey,
    CachedPrayerTimesModel cached,
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) {
    final ageSeconds =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 - cached.cachedAt;
    if (ageSeconds < _kSoftTtlSeconds) return;
    _scheduleBackgroundRefresh(dateKey, date, location, settings);
  }

  /// Pre-warm the next day's cache so the moment the calendar rolls over
  /// the app already has data — even if the user opens it offline at 12:01am.
  /// No-op when an entry already exists and is valid for the current
  /// location/settings, or when the device is offline.
  void _maybePrewarmNextDay(
    DateTime today,
    LocationData location,
    PrayerSettings settings,
  ) {
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowKey = _formatDateKey(tomorrow);
    final cached = localDataSource.getCachedPrayerTimes(tomorrowKey);
    if (cached != null &&
        cached.invalidationReason(tomorrow, location, settings) == null) {
      return; // Already pre-warmed.
    }
    _scheduleBackgroundRefresh(tomorrowKey, tomorrow, location, settings);
  }

  /// Single entry point that enforces the in-flight dedup invariant. All
  /// background fetches (SWR, pre-warm, fetch-failure retry) go through here.
  void _scheduleBackgroundRefresh(
    String dateKey,
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) {
    if (_inFlightRefreshes.contains(dateKey)) return;
    _inFlightRefreshes.add(dateKey);
    unawaited(_backgroundRefresh(dateKey, date, location, settings));
  }

  Future<void> _backgroundRefresh(
    String dateKey,
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) async {
    try {
      if (!await connectivity.isOnline()) {
        AppLogger.debug('Skipping background refresh for $dateKey (offline)');
        return;
      }
      AppLogger.info('Background refresh for $dateKey');

      final response = await remoteDataSource.fetchPrayerTimes(
        date: date,
        latitude: location.latitude,
        longitude: location.longitude,
        method: settings.calculationMethod,
        school: settings.madhab,
      );
      final newModel = CachedPrayerTimesModel.fromApiResponse(
        response,
        location,
        settings,
      );
      await localDataSource.cachePrayerTimes(newModel);

      if (!_cacheUpdatesController.isClosed) {
        _cacheUpdatesController.add(dateKey);
      }
      AppLogger.info('Background refresh succeeded for $dateKey');
    } catch (e) {
      // Silently swallow per offline-first contract — UI already has cache
      // (or will fall back via resolveCachedPrayerTimes on the next read).
      AppLogger.warning('Background refresh failed for $dateKey: $e');
    } finally {
      _inFlightRefreshes.remove(dateKey);
    }
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
