import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';

/// Repository interface for Quran data operations
///
/// Defines the contract for all Quran-related data operations.
/// Implementations should handle offline-first logic and error handling.
abstract class QuranRepository {
  /// Get all Surahs (1-114)
  ///
  /// Returns Either<Failure, List<Surah>>
  /// - Right: List of all Surahs
  /// - Left: Failure (NetworkFailure, CacheFailure, etc.)
  Future<Either<Failure, List<Surah>>> getAllSurahs();

  /// Get all Ayahs for a specific Surah
  ///
  /// [surahId] - The Surah number (1-114)
  ///
  /// Returns Either<Failure, List<Ayah>>
  /// - Right: List of Ayahs for the specified Surah
  /// - Left: Failure (NetworkFailure, CacheFailure, etc.)
  Future<Either<Failure, List<Ayah>>> getSurahById(int surahId);

  /// Search Ayahs by text (full-text search in English translation)
  ///
  /// [query] - Search query string
  ///
  /// Returns Either<Failure, List<Ayah>>
  /// - Right: List of matching Ayahs
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, List<Ayah>>> searchAyahs(String query);

  /// Add a bookmark for an Ayah
  ///
  /// [bookmark] - Bookmark to add
  ///
  /// Returns Either<Failure, void>
  /// - Right: Success
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, void>> addBookmark(Bookmark bookmark);

  /// Remove a bookmark
  ///
  /// [surahId] - The Surah ID
  /// [ayahId] - The Ayah ID
  ///
  /// Returns Either<Failure, void>
  /// - Right: Success
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, void>> removeBookmark(int surahId, int ayahId);

  /// Get all bookmarks
  ///
  /// Returns Either<Failure, List<Bookmark>>
  /// - Right: List of all bookmarks (sorted by created_at DESC)
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, List<Bookmark>>> getBookmarks();

  /// Check if an Ayah is bookmarked
  ///
  /// [surahId] - The Surah ID
  /// [ayahId] - The Ayah ID
  ///
  /// Returns Either<Failure, bool>
  /// - Right: true if bookmarked, false otherwise
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, bool>> isBookmarked(int surahId, int ayahId);

  /// Save last read position
  ///
  /// [lastRead] - Last read position to save
  ///
  /// Returns Either<Failure, void>
  /// - Right: Success
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, void>> saveLastRead(LastRead lastRead);

  /// Get last read position
  ///
  /// Returns Either<Failure, LastRead?>
  /// - Right: LastRead object or null if not set
  /// - Left: Failure (DatabaseFailure, etc.)
  Future<Either<Failure, LastRead?>> getLastRead();
}
