import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to get all Surahs (1-114)
class GetAllSurahsUseCase {
  final QuranRepository repository;

  const GetAllSurahsUseCase(this.repository);

  /// Execute the use case
  Future<Either<Failure, List<Surah>>> call() async {
    return await repository.getAllSurahs();
  }
}
