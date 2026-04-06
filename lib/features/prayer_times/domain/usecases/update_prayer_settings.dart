import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// Use case for updating prayer settings in local storage
class UpdatePrayerSettingsUseCase {
  final PrayerTimesRepository repository;

  const UpdatePrayerSettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(PrayerSettings settings) async {
    return await repository.updateSettings(settings);
  }
}
