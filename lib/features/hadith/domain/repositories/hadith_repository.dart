import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';

abstract class HadithRepository {
  /// Fetch the 6 major hadith collections (API-first, SQLite cache fallback).
  Future<Either<Failure, List<HadithCollection>>> getCollections();

  /// Fetch a page of hadiths for [collection]. Page is 1-based.
  Future<Either<Failure, List<Hadith>>> getHadiths({
    required String collection,
    required int page,
    required int limit,
  });

  /// Search cached hadiths in SQLite by English or Arabic text.
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    String? collection,
  });
}
