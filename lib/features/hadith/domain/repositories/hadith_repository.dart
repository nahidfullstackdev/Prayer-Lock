import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';

abstract class HadithRepository {
  /// Fetch all supported hadith collections (API-first, SQLite cache fallback).
  Future<Either<Failure, List<HadithCollection>>> getCollections();

  /// Fetch a page of hadiths for [collection] in the requested [languages].
  ///
  /// Missing languages are fetched from the CDN and cached before returning.
  /// [page] is 1-based.
  Future<Either<Failure, List<Hadith>>> getHadiths({
    required String collection,
    required int page,
    required int limit,
    required List<String> languages,
  });

  /// Search cached hadiths in SQLite across all translation fields.
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    String? collection,
  });
}
