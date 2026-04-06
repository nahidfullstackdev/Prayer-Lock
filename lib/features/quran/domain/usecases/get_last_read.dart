import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';
import 'package:prayer_lock/features/quran/domain/repositories/quran_repository.dart';

/// UseCase to get last read position
class GetLastReadUseCase {
  final QuranRepository repository;

  const GetLastReadUseCase(this.repository);

  /// Execute the use case
  Future<Either<Failure, LastRead?>> call() async {
    return await repository.getLastRead();
  }
}
