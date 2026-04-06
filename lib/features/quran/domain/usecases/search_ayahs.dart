import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to search Ayahs by text
class SearchAyahsUseCase {
  final QuranRepository repository;

  const SearchAyahsUseCase(this.repository);

  /// Execute the use case
  ///
  /// [query] - Search query string
  Future<Either<Failure, List<Ayah>>> call(String query) async {
    // Don't search if query is empty or too short
    if (query.trim().isEmpty || query.trim().length < 2) {
      return const Right([]);
    }

    return await repository.searchAyahs(query.trim());
  }
}
