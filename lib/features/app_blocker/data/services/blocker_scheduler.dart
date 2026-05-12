import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocker_window.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Bridges prayer-time data to native window scheduling.
///
/// Every prayer adhan time becomes a [BlockerWindow] of length
/// `repository.getWindowMinutes()` (default 20 minutes). The native side
/// uses AlarmManager.setAlarmClock to fire window-start and window-end
/// broadcasts that toggle the Accessibility Service's "armed" flag.
class BlockerScheduler {
  const BlockerScheduler({required this.repository});

  final AppBlockerRepository repository;

  /// Replaces all currently-scheduled windows with windows derived from
  /// today's [prayerTimes]. Past windows (already-elapsed end times) are
  /// skipped — there's no point firing alarms for them.
  ///
  /// Returns the number of windows that were actually scheduled.
  Future<int> rescheduleForToday(PrayerTimes prayerTimes) async {
    final minutes = repository.getWindowMinutes();
    final now = DateTime.now().millisecondsSinceEpoch;
    final windows = <BlockerWindow>[];

    for (final prayer in prayerTimes.allPrayers) {
      final startMs = prayer.time.millisecondsSinceEpoch;
      final endMs = startMs + (minutes * 60 * 1000);
      if (endMs <= now) continue;
      windows.add(BlockerWindow(
        prayerId: prayer.name.index,
        startMs: startMs,
        endMs: endMs,
      ));
    }

    final result = await repository.scheduleBlockerWindows(windows);
    return result.fold(
      (f) {
        AppLogger.error('Failed to schedule blocker windows: ${f.message}');
        return 0;
      },
      (_) {
        AppLogger.info(
          'Scheduled ${windows.length} blocker window(s) of ${minutes}min each',
        );
        return windows.length;
      },
    );
  }

  /// Cancels every currently-scheduled window alarm.
  Future<void> cancelAll() async {
    await repository.cancelAllBlockerWindows();
  }
}
