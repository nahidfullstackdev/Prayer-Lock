import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/data/datasources/hadith_local_data_source.dart';
import 'package:prayer_lock/features/hadith/data/datasources/hadith_remote_data_source.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/domain/repositories/hadith_repository.dart';

/// API-first, cache-fallback implementation of [HadithRepository].
class HadithRepositoryImpl implements HadithRepository {
  final HadithRemoteDataSource remoteDataSource;
  final HadithLocalDataSource localDataSource;

  const HadithRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<HadithCollection>>> getCollections() async {
    try {
      AppLogger.info('Fetching hadith collections from API');
      final remote = await remoteDataSource.fetchCollections();
      await localDataSource.cacheCollections(remote);
      return Right(remote.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error('Network error fetching hadith collections — trying cache', e);
      try {
        final cached = await localDataSource.getCachedCollections();
        if (cached.isNotEmpty) {
          return Right(cached.map((m) => m.toEntity()).toList());
        }
      } catch (cacheErr) {
        AppLogger.error('Hadith collections cache fallback failed', cacheErr);
      }
      return Left(_dioFailure(e));
    } catch (e, st) {
      AppLogger.error('Unexpected error fetching hadith collections', e, st);
      return Left(UnknownFailure('Failed to load hadith collections: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Hadith>>> getHadiths({
    required String collection,
    required int page,
    required int limit,
  }) async {
    try {
      AppLogger.info('Fetching hadiths: $collection page=$page');
      final remote = await remoteDataSource.fetchHadiths(
        collection: collection,
        page: page,
        limit: limit,
      );
      await localDataSource.cacheHadiths(remote, page: page);
      return Right(remote.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error(
        'Network error fetching hadiths ($collection p$page) — trying cache',
        e,
      );
      try {
        final cached = await localDataSource.getCachedHadiths(
          collection: collection,
          page: page,
          limit: limit,
        );
        if (cached.isNotEmpty) {
          return Right(cached.map((m) => m.toEntity()).toList());
        }
      } catch (cacheErr) {
        AppLogger.error('Hadith cache fallback failed', cacheErr);
      }
      return Left(_dioFailure(e));
    } catch (e, st) {
      AppLogger.error('Unexpected error fetching hadiths', e, st);
      return Left(UnknownFailure('Failed to load hadiths: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    String? collection,
  }) async {
    try {
      final results = await localDataSource.searchHadiths(
        query: query,
        collection: collection,
      );
      return Right(results.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      AppLogger.error('Error searching hadiths', e, st);
      return Left(DatabaseFailure('Hadith search failed: $e'));
    }
  }

  Failure _dioFailure(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const NetworkFailure('Connection timeout. Check your internet.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure('No internet connection.');
    }
    if (e.response?.statusCode == 403) {
      return const ServerFailure(
        'Hadith API key invalid or missing. '
        'Run with --dart-define=SUNNAH_API_KEY=your_key',
      );
    }
    return ServerFailure(
      e.message ?? 'Failed to fetch hadith data from server.',
    );
  }
}
