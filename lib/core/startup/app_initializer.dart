import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/home_widget/data/services/home_widget_service.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/notification_service.dart';
import 'package:prayer_lock/features/subscription/data/services/revenuecat_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// App startup is split into two phases so the splash screen unblocks as
/// soon as humanly possible:
///
/// [runCritical]
///   Work that MUST complete before any real screen can render — storage
///   adapters / boxes the providers immediately read. Runs in parallel.
///
/// [runDeferred]
///   Work that can happen in the background while the UI is already
///   interactive. Each task is guarded so a single failure can't poison
///   the others; the whole batch is fire-and-forget from the caller's POV.
///
/// Safe defaults cover the brief window where deferred services are not
/// yet ready (isProProvider reports `unknown` → treated as free, adhan
/// scheduling is only triggered much later, etc.).
abstract final class AppInitializer {
  static bool _deferredStarted = false;

  static Future<void> runCritical() async {
    // Hive.initFlutter must precede openBox — afterwards the remaining
    // work can fan out in parallel. `PrayerTimesLocalDataSource.initialize`
    // registers its adapters *and* opens its boxes in one go.
    await Hive.initFlutter();
    await Future.wait<void>([
      Hive.openBox<dynamic>('quran_data').then((_) {}),
      Hive.openBox<dynamic>('app_blocker').then((_) {}),
      PrayerTimesLocalDataSource().initialize(),
    ]);
  }

  /// Idempotent: calling a second time is a no-op.
  static Future<void> runDeferred() async {
    if (_deferredStarted) return;
    _deferredStarted = true;
    await Future.wait<void>([
      _guard('alarm-manager', _initAlarmManager),
      _guard('timezone', _initTimezone),
      _guard('notifications', _initNotifications),
      _guard('revenuecat', RevenueCatService.configure),
      _guard('home-widget', HomeWidgetService.initialize),
    ]);
  }

  static Future<void> _guard(String label, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      AppLogger.error('Deferred init [$label] failed', e, st);
    }
  }

  static Future<void> _initAlarmManager() async {
    if (!Platform.isAndroid) return;
    await AndroidAlarmManager.initialize();
  }

  static Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      AppLogger.warning('Timezone detection failed — using UTC fallback: $e');
    }
  }

  static Future<void> _initNotifications() async {
    await NotificationService().initialize();
  }
}
