import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';

class GetInstalledAppsUseCase {
  const GetInstalledAppsUseCase(this._repository);

  final AppBlockerRepository _repository;

  Future<Either<Failure, List<BlockedApp>>> call() =>
      _repository.getInstalledApps();
}
