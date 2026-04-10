import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/repositories/hadith_repository.dart';

class GetHadithsUseCase {
  final HadithRepository repository;

  const GetHadithsUseCase(this.repository);

  Future<Either<Failure, List<Hadith>>> call({
    required String collection,
    required int page,
    required int limit,
    required List<String> languages,
  }) =>
      repository.getHadiths(
        collection: collection,
        page: page,
        limit: limit,
        languages: languages,
      );
}
