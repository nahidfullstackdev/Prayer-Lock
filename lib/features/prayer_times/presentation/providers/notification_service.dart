import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/services/adhan_audio_service.dart';
import 'package:prayer_lock/features/prayer_times/data/services/native_alarm_service.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Top-level notification-tap handler.
//
// flutter_local_notifications may invoke this from a cold start when the user
// taps a notification while the app is killed, so the handler routes through
// the [AdhanAudioService] singleton instead of capturing any closure state.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void _onNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || !payload.startsWith('prayer:')) return;
  final index = int.tryParse(payload.substring('prayer:'.length));
  if (index == null || index < 0 || index >= PrayerName.values.length) return;
  final prayer = PrayerName.values[index];
  final audio = AdhanAudioService();
  if (audio.isPlaying) {
    AppLogger.debug('Notification tap ignored — Adhan already playing');
    return;
  }
  AppLogger.info('Notification tap → resuming full Adhan for ${prayer.displayName}');
  audio.playAdhan(isFajr: prayer == PrayerName.fajr);
}

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

  // iOS only: Dart Timers that drive AdhanAudioService at prayer time while
  // the app is alive (foreground or background). Android plays the full
  // Adhan via the native notification channel sound and needs no Timer.
  final List<Timer> _iosAdhanTimers = <Timer>[];

  // ── initialise ──────────────────────────────────────────────────────────────

  @override
  Future<bool> initialize() async {
    if (_initialised) return true;
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Request permission lazily via requestPermissions(); leave false
          // here so the system prompt only appears when we explicitly ask.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }
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
      if (Platform.isIOS) {
        final plugin =
            _notifications
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
        final granted =
            await plugin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        AppLogger.info('iOS notification permission granted: $granted');
        return granted;
      }

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
    // iOS has no analog — scheduled local notifications fire exactly once
    // permission is granted.
    if (!Platform.isAndroid) return true;
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

      if (Platform.isIOS) {
        // iOS notification sounds are hard-capped at ~30s by the system and
        // can only play files bundled as `.caf` in the iOS app (Flutter assets
        // aren't visible to UNUserNotificationCenter). The Dart Timer below
        // plays the full `.mp3` via AdhanAudioService at the real prayer time —
        // but only when the app is foreground/active, since iOS suspends Dart
        // isolates shortly after backgrounding. This is the standard iOS
        // prayer-app pattern: short adhan in the system notification, full
        // adhan only if the user has the app open at fire time.
        await _scheduleIosPrayerNotification(
          id: prayer.name.index,
          fireTime: alarmTime,
          prayerName: prayer.name.displayName,
          arabicName: prayer.name.arabicName,
          adhanType: adhanType,
          minutesBefore: settings.notificationMinutesBefore,
        );
        if (adhanType != _kAdhanTypeSilent) {
          _scheduleIosAdhanTimer(
            fireTime: prayer.time,
            isFajr: prayer.name == PrayerName.fajr,
          );
        }
      } else {
        await NativeAlarmService.scheduleExactPrayerAlarm(
          id: prayer.name.index,
          timeMs: alarmTime.millisecondsSinceEpoch,
          prayerName: prayer.name.displayName,
          arabicName: prayer.name.arabicName,
          adhanType: adhanType,
          minutesBefore: settings.notificationMinutesBefore,
        );
      }
    }

    AppLogger.info('scheduleAllPrayers complete');
  }

  // ── cancel ───────────────────────────────────────────────────────────────────

  @override
  Future<void> cancelAllPrayers() async {
    if (Platform.isIOS) {
      _cancelIosAdhanTimers();
      await _notifications.cancelAll();
      return;
    }
    await NativeAlarmService.cancelAllPrayerAlarms();
  }

  // ── iOS in-app Adhan playback ───────────────────────────────────────────────

  /// Schedules a Dart [Timer] that drives [AdhanAudioService] at [fireTime].
  /// Used on iOS only — Android plays the full Adhan via its notification
  /// channel sound and needs no Dart-side Timer.
  ///
  /// Timers do not survive an app kill; the next [scheduleAllPrayers] call
  /// (triggered by [PrayerTimesNotifier.loadPrayerTimes] on app start or by
  /// a settings change) rebuilds them.
  void _scheduleIosAdhanTimer({
    required DateTime fireTime,
    required bool isFajr,
  }) {
    final delay = fireTime.difference(DateTime.now());
    if (delay.isNegative) return;
    final timer = Timer(delay, () {
      AdhanAudioService().playAdhan(isFajr: isFajr);
    });
    _iosAdhanTimers.add(timer);
  }

  void _cancelIosAdhanTimers() {
    for (final t in _iosAdhanTimers) {
      t.cancel();
    }
    _iosAdhanTimers.clear();
  }

  // ── iOS scheduling ──────────────────────────────────────────────────────────

  /// iOS uses flutter_local_notifications' zonedSchedule instead of the
  /// Android native AlarmManager path. Custom adhan sound filenames are
  /// passed through — they must be added to the Xcode Runner target as
  /// bundle resources. If absent, iOS falls back to the default system sound.
  Future<void> _scheduleIosPrayerNotification({
    required int id,
    required DateTime fireTime,
    required String prayerName,
    required String arabicName,
    required int adhanType,
    required int minutesBefore,
  }) async {
    final scheduled = tz.TZDateTime.from(fireTime, tz.local);

    final String? soundFile = switch (adhanType) {
      _kAdhanTypeFajr => 'adhan_fajr.caf',
      _kAdhanTypeStandard => 'adhan.caf',
      _ => null,
    };

    final details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: adhanType != _kAdhanTypeSilent,
        sound: soundFile,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );

    final body = minutesBefore > 0
        ? 'In $minutesBefore min — $arabicName'
        : 'It is time for $prayerName — $arabicName';

    await _notifications.zonedSchedule(
      id,
      '$prayerName Prayer',
      body,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'prayer:$id',
    );
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
