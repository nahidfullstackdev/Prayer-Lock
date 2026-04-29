import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/models/cached_prayer_times_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/location_data_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/prayer_settings_model.dart';

/// Hive-backed local data source for prayer times, settings and last location.
///
/// Singleton: `AppInitializer` constructs/initialises one instance during the
/// critical-boot phase and the Riverpod provider re-receives the same instance
/// later. Reusing one set of `late final` box handles avoids the per-call
/// `Hive.openBox(...)` round-trip the previous implementation paid on every
/// read.
///
/// Offline-first contract:
///   • All reads are synchronous in-memory Hive lookups — never block the UI.
///   • Writes stay async because Hive's persistence is async.
///   • [resolveCachedPrayerTimes] guarantees a non-null answer whenever the
///     cache holds at least one entry, falling back from exact-date → same
///     month → globally most recent. The repository relies on this so the UI
///     never sees a "no data" state when *any* cached prayer times exist.
class PrayerTimesLocalDataSource {
  PrayerTimesLocalDataSource._();
  static final PrayerTimesLocalDataSource _instance =
      PrayerTimesLocalDataSource._();
  factory PrayerTimesLocalDataSource() => _instance;

  static const String _prayerTimesBoxName = 'prayer_times_cache';
  static const String _settingsBoxName = 'prayer_settings';
  static const String _locationBoxName = 'last_location';
  static const String _settingsKey = 'settings';
  static const String _locationKey = 'last_location';
  static const int _cacheRetentionSeconds = 30 * 24 * 60 * 60; // 30 days

  late final Box<CachedPrayerTimesModel> _prayerBox;
  late final Box<PrayerSettingsModel> _settingsBox;
  late final Box<LocationDataModel> _locationBox;

  /// Shared in-flight init so concurrent callers (e.g. AppInitializer +
  /// Riverpod provider lookup on first frame) can't race the box-open path.
  Future<void>? _initFuture;

  /// Idempotent — calling more than once returns the same future.
  Future<void> initialize() => _initFuture ??= _doInitialize();

  Future<void> _doInitialize() async {
    try {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CachedPrayerTimesModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PrayerSettingsModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LocationDataModelAdapter());
      }

      final results = await Future.wait<dynamic>([
        Hive.openBox<CachedPrayerTimesModel>(_prayerTimesBoxName),
        Hive.openBox<PrayerSettingsModel>(_settingsBoxName),
        Hive.openBox<LocationDataModel>(_locationBoxName),
      ]);
      _prayerBox = results[0] as Box<CachedPrayerTimesModel>;
      _settingsBox = results[1] as Box<PrayerSettingsModel>;
      _locationBox = results[2] as Box<LocationDataModel>;

      AppLogger.info('Hive boxes initialised');
    } catch (e, stackTrace) {
      // Reset so a retry can attempt again instead of permanently caching the
      // failure on the future.
      _initFuture = null;
      AppLogger.error('Error initializing Hive', e, stackTrace);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Prayer Times Cache — read API
  // ──────────────────────────────────────────────────────────────────────────

  /// Direct exact-key lookup. Returns null if the entry is missing or the
  /// underlying read throws (corrupted record, type mismatch, etc.).
  CachedPrayerTimesModel? getCachedPrayerTimes(String dateKey) {
    try {
      return _prayerBox.get(dateKey);
    } catch (e, stackTrace) {
      AppLogger.error('Error reading cache for $dateKey', e, stackTrace);
      return null;
    }
  }

  /// Most-recently-cached entry across the whole box, regardless of date.
  /// Used as the last-resort fallback so the UI never goes blank when *any*
  /// prayer times have ever been fetched.
  CachedPrayerTimesModel? getLatestCache() {
    try {
      if (_prayerBox.isEmpty) return null;
      // Single-pass O(n) scan — no sort, since the box is bounded to ~30
      // entries by `_cleanupOldCache` and we only need the max.
      CachedPrayerTimesModel? best;
      for (final entry in _prayerBox.values) {
        if (best == null || entry.cachedAt > best.cachedAt) best = entry;
      }
      return best;
    } catch (e, stackTrace) {
      AppLogger.error('Error finding latest cache', e, stackTrace);
      return null;
    }
  }

  /// Latest cached entry whose `dateKey` falls in the same year+month as
  /// [date]. Tier-2 fallback: a same-month entry is calendar-close enough
  /// that prayer times will be reasonably representative.
  CachedPrayerTimesModel? getLatestCacheInMonth(DateTime date) {
    try {
      if (_prayerBox.isEmpty) return null;
      final prefix = _formatDateKey(date).substring(0, 7); // 'yyyy-MM'
      CachedPrayerTimesModel? best;
      for (final entry in _prayerBox.values) {
        if (!entry.dateKey.startsWith(prefix)) continue;
        // dateKey lexicographic compare == calendar order for yyyy-MM-dd.
        if (best == null || entry.dateKey.compareTo(best.dateKey) > 0) {
          best = entry;
        }
      }
      return best;
    } catch (e, stackTrace) {
      AppLogger.error('Error finding monthly cache', e, stackTrace);
      return null;
    }
  }

  /// 3-tier fallback resolver. Returns null only when the cache is completely
  /// empty.
  ///
  ///   1. Exact `dateKey` match.
  ///   2. Latest entry within the same year+month.
  ///   3. Globally most-recently-cached entry.
  ///
  /// Logs which tier was hit so "why is the UI showing yesterday's times?"
  /// is answerable from the logs.
  CachedPrayerTimesModel? resolveCachedPrayerTimes({
    required String dateKey,
    required DateTime date,
  }) {
    final exact = getCachedPrayerTimes(dateKey);
    if (exact != null) {
      AppLogger.debug('Cache resolve: exact hit for $dateKey');
      return exact;
    }
    final monthly = getLatestCacheInMonth(date);
    if (monthly != null) {
      AppLogger.warning(
        'Cache resolve: same-month fallback ${monthly.dateKey} '
        '(requested $dateKey)',
      );
      return monthly;
    }
    final global = getLatestCache();
    if (global != null) {
      AppLogger.warning(
        'Cache resolve: global-latest fallback ${global.dateKey} '
        '(requested $dateKey)',
      );
      return global;
    }
    AppLogger.warning('Cache resolve: empty — no entries available');
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Prayer Times Cache — write API
  // ──────────────────────────────────────────────────────────────────────────

  /// Cache a fetched response and trim entries older than 30 days.
  Future<void> cachePrayerTimes(CachedPrayerTimesModel model) async {
    try {
      await _prayerBox.put(model.dateKey, model);
      AppLogger.info('Cached prayer times for ${model.dateKey}');
      await _cleanupOldCache();
    } catch (e, stackTrace) {
      AppLogger.error('Error caching prayer times', e, stackTrace);
      rethrow;
    }
  }

  Future<void> _cleanupOldCache() async {
    try {
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final stale = <dynamic>[];
      for (final entry in _prayerBox.toMap().entries) {
        if (nowSecs - entry.value.cachedAt > _cacheRetentionSeconds) {
          stale.add(entry.key);
        }
      }
      if (stale.isNotEmpty) {
        await _prayerBox.deleteAll(stale);
        AppLogger.info('Cleaned up ${stale.length} stale cache entries');
      }
    } catch (e, stackTrace) {
      // Cleanup failures are non-fatal — the next write will retry.
      AppLogger.error('Error cleaning up old cache', e, stackTrace);
    }
  }

  Future<void> clearPrayerTimesCache() async {
    try {
      await _prayerBox.clear();
      AppLogger.info('Cleared all cached prayer times');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing cache', e, stackTrace);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Settings
  // ──────────────────────────────────────────────────────────────────────────

  /// Sync read — returns persisted settings or seeds defaults on first run.
  /// The default-seed write is fire-and-forget so the caller never blocks.
  PrayerSettingsModel getSettings() {
    try {
      final settings = _settingsBox.get(_settingsKey);
      if (settings != null) {
        AppLogger.debug('Retrieved prayer settings');
        return settings;
      }

      AppLogger.debug('No settings found — seeding defaults');
      final defaults = PrayerSettingsModel(
        calculationMethod: 2, // ISNA
        madhab: 0, // Shafi
        notificationsEnabled: {
          'fajr': true,
          'dhuhr': true,
          'asr': true,
          'maghrib': true,
          'isha': true,
        },
        notificationMinutesBefore: 0,
      );
      unawaited(_settingsBox.put(_settingsKey, defaults));
      return defaults;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting settings', e, stackTrace);
      rethrow;
    }
  }

  Future<void> saveSettings(PrayerSettingsModel settings) async {
    try {
      await _settingsBox.put(_settingsKey, settings);
      AppLogger.info('Saved prayer settings');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving settings', e, stackTrace);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Location
  // ──────────────────────────────────────────────────────────────────────────

  LocationDataModel? getLastLocation() {
    try {
      return _locationBox.get(_locationKey);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting last location', e, stackTrace);
      return null;
    }
  }

  Future<void> saveLocation(LocationDataModel location) async {
    try {
      await _locationBox.put(_locationKey, location);
      AppLogger.info(
        'Saved location: ${location.latitude}, ${location.longitude}',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error saving location', e, stackTrace);
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────────────────────────────────

  static String _formatDateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
