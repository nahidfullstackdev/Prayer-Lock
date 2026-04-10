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
///
/// Uses the fawazahmed0/hadith-api CDN. On first open of a collection, full
/// editions are fetched per language and cached in SQLite. Subsequent reads
/// are served entirely from SQLite with local pagination.
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
      AppLogger.info('Fetching hadith collections from CDN');
      final remote = await remoteDataSource.fetchEditions();
      await localDataSource.cacheCollections(remote);
      return Right(remote.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error(
        'Network error fetching hadith collections — trying cache',
        e,
      );
      try {
        final cached = await localDataSource.getCachedCollections();
        if (cached.isNotEmpty) {
          return Right(cached.map((m) => m.toEntity()).toList());
        }
      } catch (cacheErr) {
        AppLogger.error(
          'Hadith collections cache fallback failed',
          cacheErr,
        );
      }
      return Left(_dioFailure(e));
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error fetching hadith collections',
        e,
        st,
      );
      return Left(UnknownFailure('Failed to load hadith collections: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Hadith>>> getHadiths({
    required String collection,
    required int page,
    required int limit,
    required List<String> languages,
  }) async {
    try {
      // Determine which languages still need to be fetched from the CDN
      final alreadyCached =
          await localDataSource.getLanguagesCachedForCollection(collection);
      final toFetch =
          languages.where((l) => !alreadyCached.contains(l)).toList();

      if (toFetch.isNotEmpty) {
        AppLogger.info(
          'Fetching languages $toFetch for $collection from CDN',
        );
        // Fetch all missing language editions in parallel
        await Future.wait(
          toFetch.map((langCode) async {
            try {
              final hadiths = await remoteDataSource.fetchHadithsForEdition(
                bookKey: collection,
                langCode: langCode,
              );
              await localDataSource.cacheHadithsForLanguage(
                collection: collection,
                langCode: langCode,
                hadiths: hadiths,
              );
            } on DioException catch (e) {
              // Log but don't fail the whole request — serve what we have
              AppLogger.error(
                'Failed to fetch [$langCode] for $collection: ${e.message}',
              );
            }
          }),
        );
      }

      // Serve from local cache with pagination
      final models = await localDataSource.getHadithsPage(
        collection: collection,
        page: page,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      AppLogger.error(
        'Network error fetching hadiths ($collection p$page) — trying cache',
        e,
      );
      try {
        final cached = await localDataSource.getHadithsPage(
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
    return ServerFailure(
      e.message ?? 'Failed to fetch hadith data from server.',
    );
  }
}
