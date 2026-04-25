import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';

/// Thin wrapper around [HomeWidget] that pushes next-prayer data to the
/// system home screen widget and asks for a redraw.
///
/// ── Keys stored in widget shared prefs ─────────────────────────────────────
///  - next_prayer_name      String  (e.g. "Dhuhr")
///  - next_prayer_arabic    String  (e.g. "الظهر")
///  - next_prayer_time      String  (formatted "HH:mm")
///  - next_prayer_countdown String  (e.g. "02h 15m" or "12m")
///  - last_updated_ms       int     (DateTime.now().millisecondsSinceEpoch)
///
/// The Android [PrayerWidgetProvider] reads these keys via
/// `HomeWidgetPlugin.getData(context)` and binds them to the layout.
class HomeWidgetService {
  HomeWidgetService._();

  static const String _androidWidgetProvider =
      'com.mdnahid.prayerlock.PrayerWidgetProvider';

  /// Must match the App Group identifier declared in the iOS widget
  /// extension entitlements once that target exists. Setting it is a
  /// no-op on platforms that ignore it, so it is safe to call on Android.
  static const String _iosAppGroupId = 'group.com.mdnahid.prayerlock.widget';

  static bool _initialised = false;

  /// Call once on app startup. Safe to call repeatedly.
  static Future<void> initialize() async {
    if (_initialised) return;
    try {
      await HomeWidget.setAppGroupId(_iosAppGroupId);
      _initialised = true;
    } catch (e, st) {
      AppLogger.error('HomeWidget.initialize failed', e, st);
    }
  }

  /// Push the upcoming prayer's data into widget storage and trigger a redraw.
  /// [countdown] is the time remaining until [prayer.time].
  static Future<void> updateNextPrayer({
    required Prayer prayer,
    required Duration countdown,
  }) async {
    await initialize();

    final time = _formatHhMm(prayer.time);
    final countdownText = _formatCountdown(countdown);

    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(
          'next_prayer_name',
          prayer.name.displayName,
        ),
        HomeWidget.saveWidgetData<String>(
          'next_prayer_arabic',
          prayer.name.arabicName,
        ),
        HomeWidget.saveWidgetData<String>('next_prayer_time', time),
        HomeWidget.saveWidgetData<String>(
          'next_prayer_countdown',
          countdownText,
        ),
        HomeWidget.saveWidgetData<int>(
          'last_updated_ms',
          DateTime.now().millisecondsSinceEpoch,
        ),
      ]);

      await HomeWidget.updateWidget(
        qualifiedAndroidName: _androidWidgetProvider,
        // iOSName is the widget extension kind declared in Swift once it exists.
        iOSName: 'PrayerWidget',
      );
    } catch (e, st) {
      AppLogger.error('HomeWidget.updateNextPrayer failed', e, st);
    }
  }

  /// Prompts the user to pin the Prayer Lock widget to the home screen.
  /// Supported on Android 8.0+ (API 26+) launchers that implement the
  /// requestPinAppWidget contract. No-ops on iOS. The plugin does not
  /// report whether the user accepted the launcher's prompt, so gate this
  /// call on [isPinWidgetSupported] and fall back to an instructional sheet
  /// when support is false.
  static Future<void> requestPinWidget() async {
    if (!Platform.isAndroid) return;
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName: _androidWidgetProvider,
      );
    } catch (e, st) {
      AppLogger.error('HomeWidget.requestPinWidget failed', e, st);
    }
  }

  /// Returns true when the launcher supports programmatic widget pinning.
  /// If false, surface a tutorial pointing the user to "long-press home →
  /// Widgets → Prayer Lock" instead.
  static Future<bool> isPinWidgetSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── formatting helpers ────────────────────────────────────────────────────

  static String _formatHhMm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatCountdown(Duration d) {
    if (d.isNegative || d == Duration.zero) return 'Now';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '<1m';
  }
}
