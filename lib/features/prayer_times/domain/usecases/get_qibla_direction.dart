import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/qibla_repository.dart';

/// Use case for getting Qibla direction from current location
class GetQiblaDirectionUseCase {
  final QiblaRepository repository;

  const GetQiblaDirectionUseCase({required this.repository});

  Future<Either<Failure, QiblaDirection>> call(LocationData location) async {
    return await repository.getQiblaDirection(location);
  }
}
