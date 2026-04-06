import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to remove a bookmark
class RemoveBookmarkUseCase {
  final QuranRepository repository;

  const RemoveBookmarkUseCase(this.repository);

  /// Execute the use case
  ///
  /// [surahId] - The Surah ID
  /// [ayahId] - The Ayah ID
  Future<Either<Failure, void>> call({
    required int surahId,
    required int ayahId,
  }) async {
    return await repository.removeBookmark(surahId, ayahId);
  }
}
