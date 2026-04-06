import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/repositories/hadith_repository.dart';

class SearchHadithsUseCase {
  final HadithRepository repository;

  const SearchHadithsUseCase(this.repository);

  Future<Either<Failure, List<Hadith>>> call({
    required String query,
    String? collection,
  }) =>
      repository.searchHadiths(query: query, collection: collection);
}
