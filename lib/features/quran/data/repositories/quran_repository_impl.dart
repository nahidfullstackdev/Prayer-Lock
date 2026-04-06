import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/data/datasources/quran_local_data_source.dart';
import 'package:prayer_lock/features/quran/data/datasources/quran_remote_data_source.dart';
import 'package:prayer_lock/features/quran/data/models/bookmark_model.dart';
import 'package:prayer_lock/features/quran/data/models/last_read_model.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// Implementation of QuranRepository with API-first logic
///
/// Strategy:
/// 1. Fetch fresh data from API
/// 2. Cache the result for offline use
/// 3. If API fails, fall back to local cache
/// 4. If both fail, return a Failure
class QuranRepositoryImpl implements QuranRepository {
  final QuranRemoteDataSource remoteDataSource;
  final QuranLocalDataSource localDataSource;

  const QuranRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<Surah>>> getAllSurahs() async {
    try {
      // API-first: always fetch fresh data
      AppLogger.info('Fetching Surahs from API');
      final remoteSurahs = await remoteDataSource.fetchAllSurahs();

      // Cache the results for offline use
      await localDataSource.cacheSurahs(remoteSurahs);

      return Right(remoteSurahs.map((model) => model.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error('Network error fetching Surahs — trying cache', e);

      // API failed: fall back to local cache
      try {
        final cachedSurahs = await localDataSource.getCachedSurahs();
        if (cachedSurahs.isNotEmpty) {
          AppLogger.info('Returning ${cachedSurahs.length} Surahs from cache');
          return Right(cachedSurahs.map((model) => model.toEntity()).toList());
        }
      } catch (cacheError) {
        AppLogger.error('Cache fallback also failed', cacheError);
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Connection timeout. Please check your internet.'));
      }
      if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection.'));
      }
      return Left(ServerFailure(e.message ?? 'Failed to fetch Surahs from server.'));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching Surahs', e, stackTrace);
      return Left(UnknownFailure('Failed to load Surahs: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Ayah>>> getSurahById(int surahId) async {
    try {
      // API-first: always fetch fresh data
      AppLogger.info('Fetching Surah $surahId from API');
      final remoteAyahs = await remoteDataSource.fetchSurahById(surahId);

      // Cache the results for offline use
      await localDataSource.cacheAyahs(remoteAyahs);

      return Right(remoteAyahs.map((model) => model.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error('Network error fetching Surah $surahId — trying cache', e);

      // API failed: fall back to local cache
      try {
        final cachedAyahs = await localDataSource.getCachedAyahs(surahId);
        if (cachedAyahs.isNotEmpty) {
          AppLogger.info('Returning ${cachedAyahs.length} cached Ayahs for Surah $surahId');
          return Right(cachedAyahs.map((model) => model.toEntity()).toList());
        }
      } catch (cacheError) {
        AppLogger.error('Cache fallback also failed', cacheError);
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const Left(NetworkFailure('Connection timeout. Please check your internet.'));
      }
      if (e.type == DioExceptionType.connectionError) {
        return const Left(NetworkFailure('No internet connection.'));
      }
      return Left(ServerFailure(e.message ?? 'Failed to fetch Surah from server.'));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching Surah $surahId', e, stackTrace);
      return Left(UnknownFailure('Failed to load Surah: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Ayah>>> searchAyahs(String query) async {
    try {
      final results = await localDataSource.searchAyahs(query);
      return Right(results.map((model) => model.toEntity()).toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error searching Ayahs', e, stackTrace);
      return Left(DatabaseFailure('Search failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> addBookmark(Bookmark bookmark) async {
    try {
      final bookmarkModel = BookmarkModel.fromEntity(bookmark);
      await localDataSource.addBookmark(bookmarkModel);
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error adding bookmark', e, stackTrace);
      return Left(DatabaseFailure('Failed to add bookmark: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeBookmark(int surahId, int ayahId) async {
    try {
      await localDataSource.removeBookmark(surahId, ayahId);
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error removing bookmark', e, stackTrace);
      return Left(DatabaseFailure('Failed to remove bookmark: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Bookmark>>> getBookmarks() async {
    try {
      final bookmarks = await localDataSource.getBookmarks();
      return Right(bookmarks.map((model) => model.toEntity()).toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error getting bookmarks', e, stackTrace);
      return Left(DatabaseFailure('Failed to load bookmarks: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> isBookmarked(int surahId, int ayahId) async {
    try {
      final isBookmarked = await localDataSource.isBookmarked(surahId, ayahId);
      return Right(isBookmarked);
    } catch (e, stackTrace) {
      AppLogger.error('Error checking bookmark status', e, stackTrace);
      return Left(DatabaseFailure('Failed to check bookmark: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveLastRead(LastRead lastRead) async {
    try {
      final lastReadModel = LastReadModel.fromEntity(lastRead);
      await localDataSource.saveLastRead(lastReadModel);
      return const Right(null);
    } catch (e, stackTrace) {
      AppLogger.error('Error saving last read', e, stackTrace);
      return Left(DatabaseFailure('Failed to save last read: $e'));
    }
  }

  @override
  Future<Either<Failure, LastRead?>> getLastRead() async {
    try {
      final lastRead = await localDataSource.getLastRead();
      return Right(lastRead?.toEntity());
    } catch (e, stackTrace) {
      AppLogger.error('Error getting last read', e, stackTrace);
      return Left(DatabaseFailure('Failed to load last read: $e'));
    }
  }
}
