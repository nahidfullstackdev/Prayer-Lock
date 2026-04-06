import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// Use case for getting prayer settings from local storage
class GetPrayerSettingsUseCase {
  final PrayerTimesRepository repository;

  const GetPrayerSettingsUseCase(this.repository);

  Future<Either<Failure, PrayerSettings>> call() async {
    return await repository.getSettings();
  }
}
