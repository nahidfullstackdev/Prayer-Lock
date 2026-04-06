import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_local_data_source.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_native_data_source.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';

class AppBlockerRepositoryImpl implements AppBlockerRepository {
  const AppBlockerRepositoryImpl({
    required this.nativeDataSource,
    required this.localDataSource,
  });

  final AppBlockerNativeDataSource nativeDataSource;
  final AppBlockerLocalDataSource localDataSource;

  @override
  Future<Either<Failure, List<BlockedApp>>> getInstalledApps() async {
    try {
      final raw = await nativeDataSource.getInstalledApps();
      final apps =
          raw
              .map(
                (m) => BlockedApp(
                  packageName: m['packageName'] as String,
                  appName: m['appName'] as String,
                  iconBase64: m['iconBase64'] as String?,
                ),
              )
              .toList();
      return Right(apps);
    } on PlatformException catch (e) {
      AppLogger.error('getInstalledApps platform error', e);
      return Left(UnknownFailure(e.message ?? 'Failed to get installed apps'));
    } catch (e) {
      AppLogger.error('getInstalledApps error', e);
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getBlockedPackages() async {
    try {
      return Right(await localDataSource.getBlockedPackages());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> saveBlockedPackages(
    List<String> packages,
  ) async {
    try {
      await localDataSource.saveBlockedPackages(packages);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> startBlockerService(
    List<String> packages,
  ) async {
    try {
      await nativeDataSource.startBlockerService(packages);
      return const Right(unit);
    } on PlatformException catch (e) {
      return Left(
        UnknownFailure(e.message ?? 'Failed to start blocker service'),
      );
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> stopBlockerService() async {
    try {
      await nativeDataSource.stopBlockerService();
      return const Right(unit);
    } on PlatformException catch (e) {
      return Left(
        UnknownFailure(e.message ?? 'Failed to stop blocker service'),
      );
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isBlockerServiceRunning() async {
    try {
      return Right(await nativeDataSource.isBlockerServiceRunning());
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> hasUsageStatsPermission() async {
    try {
      return Right(await nativeDataSource.hasUsageStatsPermission());
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, bool>> hasOverlayPermission() async {
    try {
      return Right(await nativeDataSource.hasOverlayPermission());
    } catch (e) {
      return const Right(false);
    }
  }

  @override
  Future<Either<Failure, Unit>> openUsageStatsSettings() async {
    try {
      await nativeDataSource.openUsageStatsSettings();
      return const Right(unit);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> openOverlaySettings() async {
    try {
      await nativeDataSource.openOverlaySettings();
      return const Right(unit);
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }
}
