import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';

class StopBlockerServiceUseCase {
  const StopBlockerServiceUseCase(this._repository);

  final AppBlockerRepository _repository;

  Future<Either<Failure, Unit>> call() => _repository.stopBlockerService();
}
