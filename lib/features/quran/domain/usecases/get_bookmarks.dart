import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to get all bookmarks
class GetBookmarksUseCase {
  final QuranRepository repository;

  const GetBookmarksUseCase(this.repository);

  /// Execute the use case
  Future<Either<Failure, List<Bookmark>>> call() async {
    return await repository.getBookmarks();
  }
}
