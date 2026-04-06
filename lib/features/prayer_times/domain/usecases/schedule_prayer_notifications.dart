import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';

/// Schedules exact prayer-time alarms for all prayers that have notifications
/// enabled.  Delegates entirely to [NotificationRepository] so the domain
/// layer stays platform-independent.
class SchedulePrayerNotificationsUseCase {
  final NotificationRepository _repository;

  const SchedulePrayerNotificationsUseCase(this._repository);

  /// [prayerTimes] — today's prayer schedule.
  /// [settings]    — user preferences (minutes-before, adhan type, per-prayer toggles).
  Future<Either<Failure, void>> call({
    required PrayerTimes prayerTimes,
    required PrayerSettings settings,
  }) async {
    try {
      await _repository.scheduleAllPrayers(
        prayerTimes: prayerTimes,
        settings: settings,
      );
      return const Right(null);
    } catch (e) {
      return Left(UnknownFailure('Failed to schedule notifications: $e'));
    }
  }
}
