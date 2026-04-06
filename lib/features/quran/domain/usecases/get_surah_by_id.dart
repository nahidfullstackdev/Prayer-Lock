import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to get all Ayahs for a specific Surah
class GetSurahByIdUseCase {
  final QuranRepository repository;

  const GetSurahByIdUseCase(this.repository);

  /// Execute the use case
  ///
  /// [surahId] - The Surah number (1-114)
  Future<Either<Failure, List<Ayah>>> call(int surahId) async {
    return await repository.getSurahById(surahId);
  }
}
