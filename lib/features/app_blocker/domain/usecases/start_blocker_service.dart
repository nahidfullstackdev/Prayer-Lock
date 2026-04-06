import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';

class StartBlockerServiceUseCase {
  const StartBlockerServiceUseCase(this._repository);

  final AppBlockerRepository _repository;

  Future<Either<Failure, Unit>> call(List<String> packages) =>
      _repository.startBlockerService(packages);
}
