// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mirror the same constants used in notification_service.dart ─────────────
const String _kAdhanChannelId = 'prayer_adhan';
const String _kFajrAdhanChannelId = 'prayer_fajr_adhan';
const String _kSilentChannelId = 'prayer_silent';
const String _kAdhanTypeIndex = 'prayer_adhan_type_index';

/// Debug-only widget to fire an adhan notification instantly.
///
/// - Shows **only** in debug builds; returns [SizedBox.shrink] in release.
/// - Self-contained — no Riverpod dependency, just drop it anywhere:
///   ```dart
///   const AdhanTestWidget()
///   ```
/// - Remove the single line above when you no longer need it.
class AdhanTestWidget extends StatefulWidget {
  const AdhanTestWidget({super.key});

  @override
  State<AdhanTestWidget> createState() => _AdhanTestWidgetState();
}

class _AdhanTestWidgetState extends State<AdhanTestWidget> {
  PrayerName _selected = PrayerName.fajr;
  bool _isFiring = false;

  Future<void> _fireNow() async {
    setState(() => _isFiring = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final adhanIndex = prefs.getInt(_kAdhanTypeIndex) ?? 0;
      final adhanType =
          adhanIndex < AdhanType.values.length
              ? AdhanType.values[adhanIndex]
              : AdhanType.standard;

      final String channelId;
      final String channelName;
      final AndroidNotificationSound? sound;

      if (adhanType == AdhanType.silent) {
        channelId = _kSilentChannelId;
        channelName = 'Prayer Time Reminder';
        sound = null;
      } else if (_selected == PrayerName.fajr) {
        channelId = _kFajrAdhanChannelId;
        channelName = 'Fajr Prayer Adhan';
        sound = const RawResourceAndroidNotificationSound('adhan_fajr');
      } else {
        channelId = _kAdhanChannelId;
        channelName = 'Prayer Time Adhan';
        sound = const RawResourceAndroidNotificationSound('adhan');
      }

      final notifications = FlutterLocalNotificationsPlugin();
      await notifications.show(
        99, // ID 99 — never clashes with real prayer alarm IDs (0–4)
        '${_selected.displayName} — Prayer Time',
        '${_selected.arabicName}  •  Time to pray  [TEST]',
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
            ticker: '${_selected.displayName} prayer time – test',
          ),
        ),
      );
      AppLogger.debug(
        'AdhanTestWidget: fired test notification → ${_selected.displayName}',
      );
    } catch (e, st) {
      AppLogger.error('AdhanTestWidget: notification failed', e, st);
    } finally {
      if (mounted) setState(() => _isFiring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Hidden entirely in release builds ────────────────────────────────────
    if (!kDebugMode) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

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
          // ── Title row ───────────────────────────────────────────────────
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
          const SizedBox(height: 12),
          // ── Prayer selector chips ────────────────────────────────────────
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                PrayerName.values.map((prayer) {
                  final isSelected = prayer == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = prayer),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? cs.error
                                : cs.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.error.withValues(
                            alpha: isSelected ? 1.0 : 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        prayer.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? cs.onError : cs.error,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          // ── Fire button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isFiring ? null : _fireNow,
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                disabledBackgroundColor: cs.error.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              icon:
                  _isFiring
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onError,
                        ),
                      )
                      : const Icon(
                        Icons.notifications_active_rounded,
                        size: 18,
                      ),
              label: Text(
                _isFiring
                    ? 'Firing...'
                    : 'Fire ${_selected.displayName} Adhan Now',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
