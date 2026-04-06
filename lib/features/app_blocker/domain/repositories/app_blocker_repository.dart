import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';

abstract class AppBlockerRepository {
  Future<Either<Failure, List<BlockedApp>>> getInstalledApps();
  Future<Either<Failure, List<String>>> getBlockedPackages();
  Future<Either<Failure, Unit>> saveBlockedPackages(List<String> packages);
  Future<Either<Failure, Unit>> startBlockerService(List<String> packages);
  Future<Either<Failure, Unit>> stopBlockerService();
  Future<Either<Failure, bool>> isBlockerServiceRunning();
  Future<Either<Failure, bool>> hasUsageStatsPermission();
  Future<Either<Failure, bool>> hasOverlayPermission();
  Future<Either<Failure, Unit>> openUsageStatsSettings();
  Future<Either<Failure, Unit>> openOverlaySettings();
}
