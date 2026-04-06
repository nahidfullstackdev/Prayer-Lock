import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to add a bookmark
class AddBookmarkUseCase {
  final QuranRepository repository;

  const AddBookmarkUseCase(this.repository);

  /// Execute the use case
  ///
  /// [bookmark] - Bookmark to add
  Future<Either<Failure, void>> call(Bookmark bookmark) async {
    return await repository.addBookmark(bookmark);
  }
}
