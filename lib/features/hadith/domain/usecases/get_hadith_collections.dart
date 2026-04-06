import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/domain/repositories/hadith_repository.dart';

class GetHadithCollectionsUseCase {
  final HadithRepository repository;

  const GetHadithCollectionsUseCase(this.repository);

  Future<Either<Failure, List<HadithCollection>>> call() =>
      repository.getCollections();
}
