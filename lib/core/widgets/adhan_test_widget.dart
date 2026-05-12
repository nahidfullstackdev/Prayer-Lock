import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_native_data_source.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocker_window.dart';
import 'package:prayer_lock/features/prayer_times/data/services/native_alarm_service.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

// ── Mirror the same constants used in notification_service.dart ─────────────
const String _kAdhanChannelId = 'prayer_adhan';
const String _kFajrAdhanChannelId = 'prayer_fajr_adhan';
const String _kSilentChannelId = 'prayer_silent';
const String _kAdhanTypeIndex = 'prayer_adhan_type_index';

// adhan_type encoding the native receiver expects
const int _kAdhanTypeStandard = 0;
const int _kAdhanTypeFajr = 1;
const int _kAdhanTypeSilent = 2;

// Test alarm/notification ID — outside the 0–4 range used by real prayers.
// Also outside the boot receiver's PRAYER_COUNT loop, so a stale prefs entry
// is a no-op even if the user kills the app between scheduling and firing.
const int _kTestAlarmId = 99;

// Window length used when arming the App Blocker alongside a test adhan.
// Short enough to verify behaviour quickly without waiting through the
// production 20-minute window.
const int _kTestBlockerWindowMinutes = 5;

/// Debug-only widget for smoke-testing the prayer notification pipeline.
///
/// - **Now** — bypasses AlarmManager and calls `notifications.show()` directly.
///   Fastest way to confirm a notification channel + sound asset are wired up
///   correctly, but does NOT exercise the production scheduling path.
/// - **15s / 30s / 1m / 2m / 5m** — schedules through the real pipeline:
///     • Android → [NativeAlarmService.scheduleExactPrayerAlarm] →
///       AlarmManager.setExactAndAllowWhileIdle → [PrayerAlarmReceiver]
///     • iOS → flutter_local_notifications.zonedSchedule (mirrors
///       [NotificationService] so the test is faithful)
///   Background or kill the app after tapping to confirm it survives.
///
/// Hidden in release builds. Drop in anywhere as `const AdhanTestWidget()`.
class AdhanTestWidget extends StatefulWidget {
  const AdhanTestWidget({super.key});

  @override
  State<AdhanTestWidget> createState() => _AdhanTestWidgetState();
}

class _AdhanTestWidgetState extends State<AdhanTestWidget> {
  PrayerName _selectedPrayer = PrayerName.fajr;
  // Default to 30s scheduled so the production AlarmManager path is the
  // out-of-the-box smoke test, not the immediate `show()` shortcut.
  Duration _selectedDelay = const Duration(seconds: 30);
  bool _isWorking = false;
  // Android-only: when true, the test also schedules a BlockerWindow
  // matching the adhan time so the Accessibility Service arms in lockstep.
  bool _armBlockerWindow = false;

  final _blockerNative = AppBlockerNativeDataSource();

  static const List<Duration> _delayOptions = <Duration>[
    Duration.zero,
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    // Crosses the Doze boundary (~1h screen-off) — only this length surfaces
    // the Fajr-class failure mode. Pick it, lock the device, leave it aside.
    Duration(hours: 2),
  ];

  // ── adhan-type resolution ───────────────────────────────────────────────────

  /// Reads the current adhan preference and translates it (plus the selected
  /// prayer) into the integer encoding [PrayerAlarmReceiver] expects.
  Future<int> _resolveAdhanTypeCode() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kAdhanTypeIndex) ?? 0;
    final adhan = idx < AdhanType.values.length
        ? AdhanType.values[idx]
        : AdhanType.standard;

    if (adhan == AdhanType.silent) return _kAdhanTypeSilent;
    if (_selectedPrayer == PrayerName.fajr) return _kAdhanTypeFajr;
    return _kAdhanTypeStandard;
  }

  // ── actions ─────────────────────────────────────────────────────────────────

  Future<void> _fire() async {
    setState(() => _isWorking = true);
    try {
      if (_selectedDelay == Duration.zero) {
        await _fireImmediate();
      } else {
        await _scheduleDelayed();
      }
      if (Platform.isAndroid && _armBlockerWindow) {
        await _armBlockerForTest();
      }
    } catch (e, st) {
      AppLogger.error('AdhanTestWidget._fire failed', e, st);
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Schedules a single [BlockerWindow] aligned with the test adhan so the
  /// Accessibility Service arms exactly when the notification fires.
  ///
  /// Replaces every currently-scheduled window — that includes today's real
  /// prayer windows. Surfaced in the UI hint below the toggle.
  Future<void> _armBlockerForTest() async {
    final startMs = DateTime.now()
        .add(_selectedDelay)
        .millisecondsSinceEpoch;
    final endMs = startMs + (_kTestBlockerWindowMinutes * 60 * 1000);
    await _blockerNative.scheduleBlockerWindows([
      BlockerWindow(
        prayerId: _selectedPrayer.index,
        startMs: startMs,
        endMs: endMs,
      ),
    ]);
    AppLogger.info(
      '[AdhanTest] Armed blocker window prayer=${_selectedPrayer.displayName} '
      'start=$startMs end=$endMs (${_kTestBlockerWindowMinutes}m)',
    );
  }

  /// Posts the notification immediately via the plugin. Bypasses AlarmManager
  /// entirely — useful only for verifying channels/sounds.
  Future<void> _fireImmediate() async {
    final adhanCode = await _resolveAdhanTypeCode();

    final String channelId;
    final String channelName;
    final AndroidNotificationSound? sound;
    if (adhanCode == _kAdhanTypeSilent) {
      channelId = _kSilentChannelId;
      channelName = 'Prayer Time Reminder';
      sound = null;
    } else if (adhanCode == _kAdhanTypeFajr) {
      channelId = _kFajrAdhanChannelId;
      channelName = 'Fajr Prayer Adhan';
      sound = const RawResourceAndroidNotificationSound('adhan_fajr');
    } else {
      channelId = _kAdhanChannelId;
      channelName = 'Prayer Time Adhan';
      sound = const RawResourceAndroidNotificationSound('adhan');
    }

    final iosSound = switch (adhanCode) {
      _kAdhanTypeFajr => 'adhan_fajr.caf',
      _kAdhanTypeStandard => 'adhan.caf',
      _ => null,
    };

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.show(
      _kTestAlarmId,
      '${_selectedPrayer.displayName} — Prayer Time [TEST]',
      '${_selectedPrayer.arabicName}  •  Time to pray',
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.max,
          priority: Priority.max,
          sound: sound,
          playSound: adhanCode != _kAdhanTypeSilent,
          enableVibration: true,
          visibility: NotificationVisibility.public,
          ticker: '${_selectedPrayer.displayName} prayer time – test',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: adhanCode != _kAdhanTypeSilent,
          sound: iosSound,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
    AppLogger.info(
      '[AdhanTest] Immediate → ${_selectedPrayer.displayName} adhan=$adhanCode',
    );
    _toast('Fired ${_selectedPrayer.displayName} now');
  }

  /// Schedules through the real pipeline so the production code is exercised.
  Future<void> _scheduleDelayed() async {
    final adhanCode = await _resolveAdhanTypeCode();
    final fireAt = DateTime.now().add(_selectedDelay);

    if (Platform.isAndroid) {
      // Real production path — survives app kill because PrayerAlarmReceiver
      // runs in the Android process, not a Dart isolate.
      await NativeAlarmService.scheduleExactPrayerAlarm(
        id: _kTestAlarmId,
        timeMs: fireAt.millisecondsSinceEpoch,
        prayerName: '${_selectedPrayer.displayName} [TEST]',
        arabicName: _selectedPrayer.arabicName,
        adhanType: adhanCode,
        minutesBefore: 0,
      );
    } else {
      // iOS mirror of NotificationService._scheduleIosPrayerNotification.
      final iosSound = switch (adhanCode) {
        _kAdhanTypeFajr => 'adhan_fajr.caf',
        _kAdhanTypeStandard => 'adhan.caf',
        _ => null,
      };
      final scheduled = tz.TZDateTime.from(fireAt, tz.local);

      await FlutterLocalNotificationsPlugin().zonedSchedule(
        _kTestAlarmId,
        '${_selectedPrayer.displayName} Prayer [TEST]',
        '${_selectedPrayer.arabicName}  •  Time to pray',
        scheduled,
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: adhanCode != _kAdhanTypeSilent,
            sound: iosSound,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'prayer_test:$_kTestAlarmId',
      );
    }

    AppLogger.info(
      '[AdhanTest] Scheduled ${_selectedPrayer.displayName} '
      'adhan=$adhanCode at ${fireAt.toIso8601String()} '
      '(in ${_formatDelay(_selectedDelay)})',
    );
    _toast(
      'Scheduled ${_selectedPrayer.displayName} in ${_formatDelay(_selectedDelay)}.\n'
      'You can background or kill the app now.',
    );
  }

  Future<void> _cancelTest() async {
    setState(() => _isWorking = true);
    try {
      if (Platform.isAndroid) {
        await NativeAlarmService.cancelPrayerAlarm(_kTestAlarmId);
        if (_armBlockerWindow) {
          await _blockerNative.cancelAllBlockerWindows();
        }
      } else {
        await FlutterLocalNotificationsPlugin().cancel(_kTestAlarmId);
      }
      AppLogger.info('[AdhanTest] Cancelled test alarm');
      _toast('Cancelled scheduled test');
    } catch (e, st) {
      AppLogger.error('AdhanTestWidget._cancelTest failed', e, st);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  String _formatDelay(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) {
      if (d.inSeconds % 60 == 0) return '${d.inMinutes}m';
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    if (d.inMinutes % 60 == 0) return '${d.inHours}h';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String _delayLabel(Duration d) =>
      d == Duration.zero ? 'Now' : _formatDelay(d);

  void _toast(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isImmediate = _selectedDelay == Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.error.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ───────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.bug_report_rounded, size: 16, color: cs.error),
              const SizedBox(width: 6),
              Text(
                'Adhan Test',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.error,
                ),
              ),
              const Spacer(),
              Text(
                'DEBUG ONLY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: cs.error.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Prayer selector ─────────────────────────────────────────────────
          _SectionLabel('Prayer', cs: cs),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: PrayerName.values.map((prayer) {
              return _Chip(
                label: prayer.displayName,
                selected: prayer == _selectedPrayer,
                cs: cs,
                onTap: () => setState(() => _selectedPrayer = prayer),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ── Delay selector ──────────────────────────────────────────────────
          _SectionLabel('Fire after', cs: cs),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _delayOptions.map((d) {
              return _Chip(
                label: _delayLabel(d),
                selected: d == _selectedDelay,
                cs: cs,
                onTap: () => setState(() => _selectedDelay = d),
              );
            }).toList(),
          ),

          // ── App Blocker arm toggle (Android only) ───────────────────────────
          if (Platform.isAndroid) ...[
            const SizedBox(height: 14),
            _SectionLabel('App Blocker', cs: cs),
            const SizedBox(height: 6),
            InkWell(
              onTap: _isWorking
                  ? null
                  : () => setState(
                        () => _armBlockerWindow = !_armBlockerWindow,
                      ),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 22,
                      child: Switch(
                        value: _armBlockerWindow,
                        onChanged: _isWorking
                            ? null
                            : (v) => setState(() => _armBlockerWindow = v),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Also arm App Blocker for a '
                        '$_kTestBlockerWindowMinutes-minute window',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_armBlockerWindow) ...[
              const SizedBox(height: 4),
              Text(
                'Requires: Accessibility Service enabled, Overlay permission '
                'granted, at least one app selected, auto-blocking ON. '
                'Replaces today’s real blocker schedule — re-toggle '
                'auto-blocking in App Blocker settings to restore.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: cs.error.withValues(alpha: 0.75),
                  height: 1.35,
                ),
              ),
            ],
          ],

          const SizedBox(height: 14),

          // ── Fire button ─────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isWorking ? null : _fire,
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                disabledBackgroundColor: cs.error.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon: _isWorking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onError,
                      ),
                    )
                  : Icon(
                      isImmediate
                          ? Icons.notifications_active_rounded
                          : Icons.alarm_rounded,
                      size: 18,
                    ),
              label: Text(
                _isWorking
                    ? 'Working...'
                    : isImmediate
                        ? 'Fire ${_selectedPrayer.displayName} Now'
                        : 'Schedule ${_selectedPrayer.displayName} in ${_formatDelay(_selectedDelay)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          // ── Hint + cancel (only when scheduled) ─────────────────────────────
          if (!isImmediate) ...[
            const SizedBox(height: 8),
            Text(
              'Routes through AlarmManager (Android) / zonedSchedule (iOS). '
              'Background or kill the app after tapping to verify survival. '
              'Pick 2h, lock the device, and leave it aside — that is the '
              'only delay that crosses the Doze boundary and reproduces the '
              'Fajr-class failure mode.',
              style: TextStyle(
                fontSize: 11,
                color: cs.error.withValues(alpha: 0.75),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isWorking ? null : _cancelTest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text(
                  'Cancel scheduled test',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Local presentation helpers ────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: cs.error.withValues(alpha: 0.85),
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.error : cs.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cs.error.withValues(alpha: selected ? 1.0 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? cs.onError : cs.error,
          ),
        ),
      ),
    );
  }
}
