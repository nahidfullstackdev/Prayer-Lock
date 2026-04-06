import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_remote_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/models/cached_prayer_times_model.dart';
import 'package:prayer_lock/features/prayer_times/data/models/prayer_settings_model.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';

/// Implementation of PrayerTimesRepository with offline-first caching
class PrayerTimesRepositoryImpl implements PrayerTimesRepository {
  final PrayerTimesRemoteDataSource remoteDataSource;
  final PrayerTimesLocalDataSource localDataSource;

  const PrayerTimesRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, PrayerTimes>> getPrayerTimes({
    required DateTime date,
    required LocationData location,
    required PrayerSettings settings,
  }) async {
    try {
      // Create cache key: 'yyyy-MM-dd'
      final dateKey = _formatDateKey(date);

      // OFFLINE-FIRST: Try cache first
      final cached = await localDataSource.getCachedPrayerTimes(dateKey);

      if (cached != null && cached.isValidFor(date, location, settings)) {
        AppLogger.info('✓ Returning prayer times from cache for $dateKey');
        return Right(cached.toEntity(settings.notificationsEnabled));
      }

      // Cache miss or invalid: Fetch from API
      AppLogger.info('✗ Cache miss/invalid, fetching from Aladhan API');

      final response = await remoteDataSource.fetchPrayerTimes(
        date: date,
        latitude: location.latitude,
        longitude: location.longitude,
        method: settings.calculationMethod,
        school: settings.madhab,
      );

      // Parse response and create cache model
      final cacheModel = CachedPrayerTimesModel.fromApiResponse(
        response,
        location,
        settings,
      );

      // Cache for future use
      await localDataSource.cachePrayerTimes(cacheModel);

      return Right(cacheModel.toEntity(settings.notificationsEnabled));
    } on DioException catch (e) {
      AppLogger.error('Network error fetching prayer times', e);

      // Try to return stale cache as fallback
      final dateKey = _formatDateKey(date);
      final cached = await localDataSource.getCachedPrayerTimes(dateKey);

      if (cached != null) {
        AppLogger.warning('⚠ Network failed, returning stale cache');
        return Right(cached.toEntity(settings.notificationsEnabled));
      }

      // No cache available - return appropriate failure
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const Left(
          NetworkFailure('No internet connection. Please check your network.'),
        );
      }

      if (e.response?.statusCode != null) {
        return Left(
          ServerFailure(
            'Server error (${e.response!.statusCode}). Please try again later.',
          ),
        );
      }

      return Left(ServerFailure(e.message ?? 'Failed to fetch prayer times'));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching prayer times', e, stackTrace);
      return Left(UnknownFailure('Failed to load prayer times: $e'));
    }
  }

  @override
  Future<Either<Failure, PrayerSettings>> getSettings() async {
    try {
      final model = await localDataSource.getSettings();
      return Right(model.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('Error getting prayer settings', e, stackTrace);
      return Left(CacheFailure('Failed to load settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSettings(PrayerSettings settings) async {
    try {
      final model = PrayerSettingsModel.fromEntity(settings);
      await localDataSource.saveSettings(model);
      AppLogger.info('Prayer settings updated successfully');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error updating prayer settings', e, stackTrace);
      return Left(CacheFailure('Failed to save settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      await localDataSource.clearPrayerTimesCache();
      AppLogger.info('Prayer times cache cleared');
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error clearing cache', e, stackTrace);
      return Left(CacheFailure('Failed to clear cache: $e'));
    }
  }

  /// Format date as 'yyyy-MM-dd'
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
