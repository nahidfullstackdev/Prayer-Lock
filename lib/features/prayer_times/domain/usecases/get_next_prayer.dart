import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Use case for calculating the next upcoming prayer
class GetNextPrayerUseCase {
  const GetNextPrayerUseCase();

  /// Returns the next prayer from the current time
  /// If all prayers for today have passed, returns Fajr
  /// (Caller should fetch tomorrow's times if needed)
  Prayer call(PrayerTimes prayerTimes) {
    final now = DateTime.now();

    // Check each prayer in order
    for (final prayer in prayerTimes.allPrayers) {
      if (prayer.time.isAfter(now)) {
        return prayer;
      }
    }

    // All prayers have passed for today
    // Return Fajr (caller should handle fetching tomorrow's times)
    return prayerTimes.fajr;
  }
}
