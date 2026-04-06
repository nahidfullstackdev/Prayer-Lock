import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Domain interface for scheduling and managing prayer notifications.
/// Implemented in the presentation layer by [NotificationService].
abstract class NotificationRepository {
  /// Initialises the notification plugin and creates Android channels.
  /// Must be called once before scheduling any notifications.
  /// Returns true on success.
  Future<bool> initialize();

  /// Requests POST_NOTIFICATIONS (Android 13+) and SCHEDULE_EXACT_ALARM
  /// (Android 12+) permissions.  Returns true if all required permissions
  /// were granted.
  Future<bool> requestPermissions();

  /// Cancels existing alarms then schedules one exact alarm per enabled prayer
  /// in [prayerTimes], offset by [settings.notificationMinutesBefore].
  /// Prayers whose [notificationEnabled] flag is false are skipped.
  Future<void> scheduleAllPrayers({
    required PrayerTimes prayerTimes,
    required PrayerSettings settings,
  });

  /// Cancels all five scheduled prayer alarms.
  Future<void> cancelAllPrayers();

  /// Returns true if the app has the SCHEDULE_EXACT_ALARM permission.
  /// Always returns true on Android < 12.
  Future<bool> hasExactAlarmPermission();

  /// Opens the system settings screen where the user can grant the exact-alarm
  /// permission (Android 12+).
  Future<void> openExactAlarmSettings();
}
