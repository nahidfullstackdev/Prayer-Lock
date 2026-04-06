import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/qibla_data_source.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/qibla_repository.dart';

/// Implementation of QiblaRepository
class QiblaRepositoryImpl implements QiblaRepository {
  final QiblaDataSource dataSource;

  const QiblaRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, QiblaDirection>> getQiblaDirection(
    LocationData location,
  ) async {
    try {
      final qiblaDirection = await dataSource.getQiblaDirection(location);
      return Right(qiblaDirection);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting Qibla direction', e, stackTrace);
      return Left(UnknownFailure('Failed to get Qibla direction: $e'));
    }
  }

  @override
  Stream<double> getCompassHeadingStream() {
    try {
      return dataSource.getCompassHeadingStream();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting compass stream', e, stackTrace);
      return Stream.error(e, stackTrace);
    }
  }
}
