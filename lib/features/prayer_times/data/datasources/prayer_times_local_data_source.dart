import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/models/cached_prayer_times_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/location_data_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/prayer_settings_model.dart';

/// Local data source for caching prayer times, settings, and location using Hive
class PrayerTimesLocalDataSource {
  static const String _prayerTimesBox = 'prayer_times_cache';
  static const String _settingsBox = 'prayer_settings';
  static const String _locationBox = 'last_location';

  /// Initialize Hive and open all boxes
  Future<void> initialize() async {
    try {
      await Hive.initFlutter();

      // Register TypeAdapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CachedPrayerTimesModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PrayerSettingsModelAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(LocationDataModelAdapter());
      }

      // Open boxes
      await Hive.openBox<CachedPrayerTimesModel>(_prayerTimesBox);
      await Hive.openBox<PrayerSettingsModel>(_settingsBox);
      await Hive.openBox<LocationDataModel>(_locationBox);

      AppLogger.info('Hive boxes initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Error initializing Hive', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Prayer Times Cache Operations ====================

  /// Get cached prayer times for a specific date
  Future<CachedPrayerTimesModel?> getCachedPrayerTimes(String dateKey) async {
    try {
      final box = await Hive.openBox<CachedPrayerTimesModel>(_prayerTimesBox);
      final cached = box.get(dateKey);

      if (cached != null) {
        AppLogger.debug('Found cached prayer times for $dateKey');
      } else {
        AppLogger.debug('No cached prayer times for $dateKey');
      }

      return cached;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting cached prayer times', e, stackTrace);
      return null;
    }
  }

  /// Cache prayer times for a date (keep for 30 days)
  Future<void> cachePrayerTimes(CachedPrayerTimesModel model) async {
    try {
      final box = await Hive.openBox<CachedPrayerTimesModel>(_prayerTimesBox);
      await box.put(model.dateKey, model);

      AppLogger.info('Cached prayer times for ${model.dateKey}');

      // Clean up old entries (older than 30 days)
      await _cleanupOldCache(box);
    } catch (e, stackTrace) {
      AppLogger.error('Error caching prayer times', e, stackTrace);
      rethrow;
    }
  }

  /// Clean up cache entries older than 30 days
  Future<void> _cleanupOldCache(
    Box<CachedPrayerTimesModel> box,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const thirtyDaysInSeconds = 30 * 24 * 60 * 60;
      final keysToDelete = <String>[];

      for (final entry in box.toMap().entries) {
        final cached = entry.value;
        final age = now - cached.cachedAt;

        if (age > thirtyDaysInSeconds) {
          keysToDelete.add(entry.key);
        }
      }

      for (final key in keysToDelete) {
        await box.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        AppLogger.info('Cleaned up ${keysToDelete.length} old cache entries');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error cleaning up old cache', e, stackTrace);
    }
  }

  /// Clear all cached prayer times
  Future<void> clearPrayerTimesCache() async {
    try {
      final box = await Hive.openBox<CachedPrayerTimesModel>(_prayerTimesBox);
      await box.clear();
      AppLogger.info('Cleared all cached prayer times');
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing cache', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Settings Operations ====================

  /// Get prayer settings
  Future<PrayerSettingsModel> getSettings() async {
    try {
      final box = await Hive.openBox<PrayerSettingsModel>(_settingsBox);
      final settings = box.get('settings');

      if (settings != null) {
        AppLogger.debug('Retrieved prayer settings');
        return settings;
      }

      // Return default settings if not found
      AppLogger.debug('No settings found, returning defaults');
      final defaultSettings = PrayerSettingsModel(
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

      // Save default settings
      await saveSettings(defaultSettings);
      return defaultSettings;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting settings', e, stackTrace);
      rethrow;
    }
  }

  /// Save prayer settings
  Future<void> saveSettings(PrayerSettingsModel settings) async {
    try {
      final box = await Hive.openBox<PrayerSettingsModel>(_settingsBox);
      await box.put('settings', settings);
      AppLogger.info('Saved prayer settings');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving settings', e, stackTrace);
      rethrow;
    }
  }

  // ==================== Location Operations ====================

  /// Get last known location
  Future<LocationDataModel?> getLastLocation() async {
    try {
      final box = await Hive.openBox<LocationDataModel>(_locationBox);
      final location = box.get('last_location');

      if (location != null) {
        AppLogger.debug('Retrieved last known location');
      } else {
        AppLogger.debug('No last known location');
      }

      return location;
    } catch (e, stackTrace) {
      AppLogger.error('Error getting last location', e, stackTrace);
      return null;
    }
  }

  /// Save location
  Future<void> saveLocation(LocationDataModel location) async {
    try {
      final box = await Hive.openBox<LocationDataModel>(_locationBox);
      await box.put('last_location', location);
      AppLogger.info(
        'Saved location: ${location.latitude}, ${location.longitude}',
      );
    } catch (e, stackTrace) {
      AppLogger.error('Error saving location', e, stackTrace);
      rethrow;
    }
  }
}
