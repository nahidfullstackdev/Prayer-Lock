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

  /// Returns the last-known permission state persisted to Hive.
  /// Used for instant UI on screen open, before native checks complete.
  Either<Failure, ({bool hasUsageStats, bool hasOverlay})> getCachedPermissions();

  /// Persists the current permission state to Hive after a native check.
  Future<Either<Failure, Unit>> savePermissions({
    required bool hasUsageStats,
    required bool hasOverlay,
  });
}
