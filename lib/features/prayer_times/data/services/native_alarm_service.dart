import 'package:flutter/services.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// Dart bridge to [PrayerAlarmChannel] on the Android side.
///
/// Uses [AlarmManager.setExactAndAllowWhileIdle] under the hood, which
/// guarantees delivery even in Doze mode — unlike android_alarm_manager_plus
/// whose AlarmService (background Dart isolate) is killed by OEM battery
/// optimization on Xiaomi, Infinix, OPPO, etc.
///
/// All methods are no-ops on non-Android platforms.
///
/// adhan_type encoding (passed to native):
///   0 — standard adhan  (adhan.mp3  — Dhuhr/Asr/Maghrib/Isha)
///   1 — Fajr adhan      (adhan_fajr.mp3)
///   2 — silent          (vibration only)
class NativeAlarmService {
  NativeAlarmService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mdnahid.prayerlock/prayer_alarm',
  );

  // ── scheduling ────────────────────────────────────────────────────────────────

  /// Schedule a single exact alarm for a prayer.
  ///
  /// [id]            — unique alarm ID (0-4, matches [PrayerName.index])
  /// [timeMs]        — fire time as UTC milliseconds since epoch
  /// [prayerName]    — English name shown in the notification, e.g. "Fajr"
  /// [arabicName]    — Arabic name shown in the notification, e.g. "الفجر"
  /// [adhanType]     — 0=standard, 1=fajr, 2=silent (see class doc)
  /// [minutesBefore] — advance offset already baked into [timeMs]; stored
  ///                   for display purposes only in the notification body
  static Future<void> scheduleExactPrayerAlarm({
    required int id,
    required int timeMs,
    required String prayerName,
    required String arabicName,
    required int adhanType,
    required int minutesBefore,
  }) async {
    try {
      await _channel.invokeMethod<void>('scheduleExactPrayerAlarm', {
        'id': id,
        'timeMs': timeMs,
        'prayerName': prayerName,
        'arabicName': arabicName,
        'adhanType': adhanType,
        'minutesBefore': minutesBefore,
      });
      AppLogger.info(
        '[NativeAlarm] Scheduled $prayerName id=$id '
        'at ${DateTime.fromMillisecondsSinceEpoch(timeMs).toIso8601String()}',
      );
    } on PlatformException catch (e, st) {
      AppLogger.error(
        '[NativeAlarm] scheduleExactPrayerAlarm failed id=$id',
        e,
        st,
      );
    }
  }

  /// Cancel a single prayer alarm by its [id] (0-4).
  static Future<void> cancelPrayerAlarm(int id) async {
    try {
      await _channel.invokeMethod<void>('cancelPrayerAlarm', {'id': id});
      AppLogger.info('[NativeAlarm] Cancelled alarm id=$id');
    } on PlatformException catch (e, st) {
      AppLogger.error('[NativeAlarm] cancelPrayerAlarm failed id=$id', e, st);
    }
  }

  /// Cancel all 5 daily prayer alarms.
  static Future<void> cancelAllPrayerAlarms() async {
    try {
      await _channel.invokeMethod<void>('cancelAllPrayerAlarms');
      AppLogger.info('[NativeAlarm] All prayer alarms cancelled');
    } on PlatformException catch (e, st) {
      AppLogger.error('[NativeAlarm] cancelAllPrayerAlarms failed', e, st);
    }
  }

  // ── battery optimisation ─────────────────────────────────────────────────────

  /// Returns true if the system is NOT applying battery optimisation to this app.
  /// Always returns true on Android < 6.0 (Doze mode didn't exist yet).
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored') ??
          false;
    } on PlatformException catch (e, st) {
      AppLogger.error(
        '[NativeAlarm] isBatteryOptimizationIgnored failed',
        e,
        st,
      );
      return false;
    }
  }

  /// Opens the system dialog that lets the user disable battery optimisation
  /// for this app ([Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS]).
  ///
  /// Requires the [REQUEST_IGNORE_BATTERY_OPTIMIZATIONS] permission in the
  /// manifest (already declared).
  static Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } on PlatformException catch (e, st) {
      AppLogger.error(
        '[NativeAlarm] openBatteryOptimizationSettings failed',
        e,
        st,
      );
    }
  }

  /// Opens the OEM-specific auto-start / protected-apps settings screen.
  ///
  /// Pass the device manufacturer string from [Build.MANUFACTURER]
  /// (lower-cased).  Supports: xiaomi, redmi, poco, oppo, realme, oneplus,
  /// vivo, huawei, honor, samsung, tecno, infinix, itel, asus, meizu, lenovo.
  /// Falls back to the standard App Info screen for unknown manufacturers.
  static Future<void> openAutoStartSettings({
    String manufacturer = '',
  }) async {
    try {
      await _channel.invokeMethod<void>('openAutoStartSettings', {
        'manufacturer': manufacturer.toLowerCase(),
      });
    } on PlatformException catch (e, st) {
      AppLogger.error('[NativeAlarm] openAutoStartSettings failed', e, st);
    }
  }
}
