import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_local_data_source.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_native_data_source.dart';
import 'package:prayer_lock/features/app_blocker/data/repositories/app_blocker_repository_impl.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_installed_apps.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/save_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/start_blocker_service.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/stop_blocker_service.dart';
import 'package:prayer_lock/features/app_blocker/presentation/providers/app_blocker_notifier.dart';

// ── Data sources ─────────────────────────────────────────────────────────────

final appBlockerLocalDataSourceProvider =
    Provider<AppBlockerLocalDataSource>((ref) {
  return AppBlockerLocalDataSource();
});

final appBlockerNativeDataSourceProvider =
    Provider<AppBlockerNativeDataSource>((ref) {
  return AppBlockerNativeDataSource();
});

// ── Repository ────────────────────────────────────────────────────────────────

final appBlockerRepositoryProvider = Provider<AppBlockerRepository>((ref) {
  return AppBlockerRepositoryImpl(
    nativeDataSource: ref.read(appBlockerNativeDataSourceProvider),
    localDataSource: ref.read(appBlockerLocalDataSourceProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final getInstalledAppsUseCaseProvider = Provider<GetInstalledAppsUseCase>(
  (ref) => GetInstalledAppsUseCase(ref.read(appBlockerRepositoryProvider)),
);

final getBlockedPackagesUseCaseProvider = Provider<GetBlockedPackagesUseCase>(
  (ref) => GetBlockedPackagesUseCase(ref.read(appBlockerRepositoryProvider)),
);

final saveBlockedPackagesUseCaseProvider = Provider<SaveBlockedPackagesUseCase>(
  (ref) => SaveBlockedPackagesUseCase(ref.read(appBlockerRepositoryProvider)),
);

final startBlockerServiceUseCaseProvider = Provider<StartBlockerServiceUseCase>(
  (ref) => StartBlockerServiceUseCase(ref.read(appBlockerRepositoryProvider)),
);

final stopBlockerServiceUseCaseProvider = Provider<StopBlockerServiceUseCase>(
  (ref) => StopBlockerServiceUseCase(ref.read(appBlockerRepositoryProvider)),
);

// ── State notifier ────────────────────────────────────────────────────────────

final appBlockerProvider =
    StateNotifierProvider<AppBlockerNotifier, AppBlockerState>((ref) {
  return AppBlockerNotifier(
    getInstalledAppsUseCase: ref.read(getInstalledAppsUseCaseProvider),
    getBlockedPackagesUseCase: ref.read(getBlockedPackagesUseCaseProvider),
    saveBlockedPackagesUseCase: ref.read(saveBlockedPackagesUseCaseProvider),
    startBlockerServiceUseCase: ref.read(startBlockerServiceUseCaseProvider),
    stopBlockerServiceUseCase: ref.read(stopBlockerServiceUseCaseProvider),
    repository: ref.read(appBlockerRepositoryProvider),
  );
});
