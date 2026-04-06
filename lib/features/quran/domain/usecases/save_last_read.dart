import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to save last read position
class SaveLastReadUseCase {
  final QuranRepository repository;

  const SaveLastReadUseCase(this.repository);

  /// Execute the use case
  ///
  /// [lastRead] - Last read position to save
  Future<Either<Failure, void>> call(LastRead lastRead) async {
    return await repository.saveLastRead(lastRead);
  }
}
