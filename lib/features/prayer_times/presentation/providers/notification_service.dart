import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences keys — written by the main isolate so the background alarm
// callback can reconstruct the correct notification without a Riverpod ref.
// ─────────────────────────────────────────────────────────────────────────────
const String _kAdhanTypeIndex = 'prayer_adhan_type_index';
const String _kMinutesBefore = 'prayer_notify_minutes_before';

// ─────────────────────────────────────────────────────────────────────────────
// Notification channel IDs
// Each channel carries a different sound; Android caches them independently.
// ─────────────────────────────────────────────────────────────────────────────
const String _kAdhanChannelId = 'prayer_adhan';
const String _kFajrAdhanChannelId = 'prayer_fajr_adhan';
const String _kSilentChannelId = 'prayer_silent';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level alarm callback — runs in a background Dart isolate.
//
// Requirements:
//   • Must be a top-level (non-closure) function.
//   • Must be annotated @pragma('vm:entry-point').
//   • android_alarm_manager_plus v3+ auto-registers plugins, so
//     FlutterLocalNotificationsPlugin and SharedPreferences both work here.
//
// Audio files (place in android/app/src/main/res/raw/):
//   adhan.mp3       — standard adhan for Dhuhr, Asr, Maghrib, Isha
//   adhan_fajr.mp3  — Fajr adhan (includes "As-salatu khayrun min an-nawm")
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> prayerAlarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    final prayerName = PrayerName.values[id];

    final prefs = await SharedPreferences.getInstance();
    final adhanIndex = prefs.getInt(_kAdhanTypeIndex) ?? 0;
    final minutesBefore = prefs.getInt(_kMinutesBefore) ?? 0;

    final adhanType =
        adhanIndex < AdhanType.values.length
            ? AdhanType.values[adhanIndex]
            : AdhanType.standard;

    // Pick channel based on adhan type and prayer name.
    final String channelId;
    final String channelName;
    final AndroidNotificationSound? sound;

    if (adhanType == AdhanType.silent) {
      channelId = _kSilentChannelId;
      channelName = 'Prayer Time Reminder';
      sound = null;
    } else if (prayerName == PrayerName.fajr) {
      channelId = _kFajrAdhanChannelId;
      channelName = 'Fajr Prayer Adhan';
      sound = const RawResourceAndroidNotificationSound('adhan_fajr');
    } else {
      channelId = _kAdhanChannelId;
      channelName = 'Prayer Time Adhan';
      sound = const RawResourceAndroidNotificationSound('adhan');
    }

    final String title;
    final String body;
    if (minutesBefore > 0) {
      title = '$minutesBefore min until ${prayerName.displayName}';
      body = '${prayerName.arabicName}  •  Prepare for prayer';
    } else {
      title = '${prayerName.displayName} — Prayer Time';
      body = '${prayerName.arabicName}  •  Time to pray';
    }

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          sound: sound,
          playSound: adhanType != AdhanType.silent,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          ticker: '${prayerName.displayName} prayer time',
        ),
      ),
    );

    AppLogger.info('Prayer notification shown → ${prayerName.displayName}');
  } catch (e, st) {
    AppLogger.error('prayerAlarmCallback error (id=$id)', e, st);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────────────────

/// Concrete [NotificationRepository] implementation.
/// Lives in the presentation layer so it can freely use platform plugins.
class NotificationService implements NotificationRepository {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── initialise ──────────────────────────────────────────────────────────────

  @override
  Future<bool> initialize() async {
    if (_initialised) return true;
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );
      await _notifications.initialize(initSettings);
      await _createNotificationChannels();
      await AndroidAlarmManager.initialize();
      _initialised = true;
      AppLogger.info('NotificationService initialised');
      return true;
    } catch (e, st) {
      AppLogger.error('NotificationService.initialize failed', e, st);
      return false;
    }
  }

  // ── permissions ─────────────────────────────────────────────────────────────

  @override
  Future<bool> requestPermissions() async {
    try {
      // POST_NOTIFICATIONS — Android 13+ (API 33+)
      final notifStatus = await Permission.notification.request();
      final granted = notifStatus.isGranted || notifStatus.isLimited;
      AppLogger.info('POST_NOTIFICATIONS: $notifStatus');

      // Warn if exact-alarm permission is missing (Android 12+)
      if (!await hasExactAlarmPermission()) {
        AppLogger.warning(
          'SCHEDULE_EXACT_ALARM not granted — alarms may be inexact',
        );
      }
      return granted;
    } catch (e, st) {
      AppLogger.error('requestPermissions error', e, st);
      return false;
    }
  }

  @override
  Future<bool> hasExactAlarmPermission() async {
    try {
      final plugin =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      return await plugin?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> openExactAlarmSettings() async {
    try {
      await openAppSettings();
    } catch (e, st) {
      AppLogger.error('openExactAlarmSettings error', e, st);
    }
  }

  // ── scheduling ───────────────────────────────────────────────────────────────

  @override
  Future<void> scheduleAllPrayers({
    required PrayerTimes prayerTimes,
    required PrayerSettings settings,
  }) async {
    if (!_initialised) await initialize();

    // Persist settings so the background-isolate callback can read them.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAdhanTypeIndex, settings.adhanType.index);
    await prefs.setInt(_kMinutesBefore, settings.notificationMinutesBefore);

    await cancelAllPrayers();

    final now = DateTime.now();
    for (final prayer in prayerTimes.allPrayers) {
      if (!(settings.notificationsEnabled[prayer.name] ?? true)) {
        AppLogger.debug('${prayer.name.displayName} notifications disabled');
        continue;
      }

      final alarmTime = prayer.time.subtract(
        Duration(minutes: settings.notificationMinutesBefore),
      );

      if (!alarmTime.isAfter(now)) {
        AppLogger.debug('${prayer.name.displayName} alarm time already passed');
        continue;
      }

      await AndroidAlarmManager.oneShotAt(
        alarmTime,
        prayer.name.index, // Unique ID 0–4
        prayerAlarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        alarmClock: true, // Bypasses Doze mode; shows in Android clock app
      );

      AppLogger.info(
        'Scheduled ${prayer.name.displayName} → ${alarmTime.toIso8601String()}',
      );
    }
  }

  // ── cancel ───────────────────────────────────────────────────────────────────

  @override
  Future<void> cancelAllPrayers() async {
    for (final prayer in PrayerName.values) {
      await AndroidAlarmManager.cancel(prayer.index);
    }
    AppLogger.info('All prayer alarms cancelled');
  }

  // ── private ──────────────────────────────────────────────────────────────────

  /// Creates the three Android 8+ notification channels.
  /// Safe to call multiple times — Android no-ops if the channel already exists.
  ///
  /// IMPORTANT: place audio files in android/app/src/main/res/raw/
  ///   adhan.mp3       — standard adhan
  ///   adhan_fajr.mp3  — Fajr adhan
  Future<void> _createNotificationChannels() async {
    final plugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (plugin == null) return;

    // Standard adhan channel
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kAdhanChannelId,
        'Prayer Time Adhan',
        description: 'Plays adhan when prayer time arrives',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      ),
    );

    // Fajr adhan channel (Salat ul Fajr adhan)
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kFajrAdhanChannelId,
        'Fajr Prayer Adhan',
        description: 'Plays Fajr adhan at dawn',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan_fajr'),
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      ),
    );

    // Silent / vibration-only channel
    await plugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _kSilentChannelId,
        'Prayer Time Reminder',
        description: 'Vibration-only prayer time reminder',
        importance: Importance.high,
        playSound: false,
        enableVibration: true,
        showBadge: true,
      ),
    );

    AppLogger.info('Notification channels ready');
  }
}
