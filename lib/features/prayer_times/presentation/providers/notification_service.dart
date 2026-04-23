import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/services/native_alarm_service.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification channel IDs
//
// These IDs must match the constants in PrayerAlarmReceiver.kt.
// Android caches channel settings independently — never reuse an ID with
// different sound/importance settings once it has been delivered to a device.
// ─────────────────────────────────────────────────────────────────────────────
const String _kAdhanChannelId = 'prayer_adhan';
const String _kFajrAdhanChannelId = 'prayer_fajr_adhan';
const String _kSilentChannelId = 'prayer_silent';

// ─────────────────────────────────────────────────────────────────────────────
// adhan_type encoding for the native layer
// ─────────────────────────────────────────────────────────────────────────────
const int _kAdhanTypeStandard = 0;
const int _kAdhanTypeFajr = 1;
const int _kAdhanTypeSilent = 2;

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService
//
// Concrete [NotificationRepository] implementation.
//
// Architecture change (v2):
//   Previous: android_alarm_manager_plus → AlarmService (background Dart isolate)
//             → FlutterLocalNotificationsPlugin.show()
//   Now:      PrayerAlarmChannel (MethodChannel) → AlarmManager.setExactAndAllowWhileIdle()
//             → PrayerAlarmReceiver (native BroadcastReceiver) → NotificationManagerCompat
//
// The native path survives battery-optimization killing that breaks the old
// Dart-isolate path on Xiaomi MIUI, Infinix HiOS, OPPO ColorOS, etc.
// ─────────────────────────────────────────────────────────────────────────────
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
      _initialised = true;
      AppLogger.info('NotificationService initialised (native-alarm mode)');
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
      final notifStatus = await Permission.notification.request();
      final granted = notifStatus.isGranted || notifStatus.isLimited;
      AppLogger.info('POST_NOTIFICATIONS: $notifStatus');

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

  /// Schedules all enabled prayer alarms for [prayerTimes] using native
  /// [AlarmManager.setExactAndAllowWhileIdle].
  ///
  /// Each prayer is scheduled as an individual exact alarm whose [PendingIntent]
  /// targets [PrayerAlarmReceiver].  Alarms already in the past are skipped.
  @override
  Future<void> scheduleAllPrayers({
    required PrayerTimes prayerTimes,
    required PrayerSettings settings,
  }) async {
    if (!_initialised) await initialize();

    // Cancel all existing alarms first to avoid duplicates when settings change.
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
        AppLogger.debug(
          '${prayer.name.displayName} alarm time already passed — skipping',
        );
        continue;
      }

      final int adhanType = _resolveAdhanType(settings.adhanType, prayer.name);

      await NativeAlarmService.scheduleExactPrayerAlarm(
        id: prayer.name.index,
        timeMs: alarmTime.millisecondsSinceEpoch,
        prayerName: prayer.name.displayName,
        arabicName: prayer.name.arabicName,
        adhanType: adhanType,
        minutesBefore: settings.notificationMinutesBefore,
      );
    }

    AppLogger.info('scheduleAllPrayers complete');
  }

  // ── cancel ───────────────────────────────────────────────────────────────────

  @override
  Future<void> cancelAllPrayers() async {
    await NativeAlarmService.cancelAllPrayerAlarms();
  }

  // ── private ──────────────────────────────────────────────────────────────────

  /// Maps [AdhanType] + [PrayerName] to the integer encoding expected by the
  /// native [PrayerAlarmReceiver]:
  ///   0 — standard adhan (adhan.mp3)
  ///   1 — Fajr adhan     (adhan_fajr.mp3)
  ///   2 — silent
  int _resolveAdhanType(AdhanType adhanType, PrayerName prayer) {
    if (adhanType == AdhanType.silent) return _kAdhanTypeSilent;
    if (prayer == PrayerName.fajr) return _kAdhanTypeFajr;
    return _kAdhanTypeStandard;
  }

  /// Creates the three Android 8+ notification channels.
  ///
  /// IMPORTANT: Channel properties (sound, importance) are immutable after
  /// first creation.  To change them you must delete and recreate under a new ID.
  /// Audio files must exist in android/app/src/main/res/raw/:
  ///   adhan.mp3       — standard adhan (Dhuhr / Asr / Maghrib / Isha)
  ///   adhan_fajr.mp3  — Fajr adhan
  Future<void> _createNotificationChannels() async {
    final plugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (plugin == null) return;

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

    AppLogger.info('Notification channels created/verified');
  }
}
