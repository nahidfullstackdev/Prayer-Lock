import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_local_data_source.dart';
import 'package:prayer_lock/features/app_blocker/data/datasources/app_blocker_native_data_source.dart';
import 'package:prayer_lock/features/app_blocker/data/repositories/app_blocker_repository_impl.dart';
import 'package:prayer_lock/features/app_blocker/data/services/blocker_scheduler.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_installed_apps.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/save_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/presentation/providers/app_blocker_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

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

// ── Scheduler service ─────────────────────────────────────────────────────────

final blockerSchedulerProvider = Provider<BlockerScheduler>((ref) {
  return BlockerScheduler(repository: ref.read(appBlockerRepositoryProvider));
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

// ── State notifier ────────────────────────────────────────────────────────────

final appBlockerProvider =
    StateNotifierProvider<AppBlockerNotifier, AppBlockerState>((ref) {
  return AppBlockerNotifier(
    getInstalledAppsUseCase: ref.read(getInstalledAppsUseCaseProvider),
    getBlockedPackagesUseCase: ref.read(getBlockedPackagesUseCaseProvider),
    saveBlockedPackagesUseCase: ref.read(saveBlockedPackagesUseCaseProvider),
    repository: ref.read(appBlockerRepositoryProvider),
    scheduler: ref.read(blockerSchedulerProvider),
  );
});

// ── Auto-rescheduler side-effect provider ────────────────────────────────────
//
// Watches `prayerTimesProvider` and reschedules the native blocker windows
// whenever today's prayer times change (cold start, day rollover, location
// change, calc-method change, SWR background refresh). No-op when the user
// has auto-blocking off.
//
// Lives here (not inside `prayerTimesProvider`'s factory) to avoid the
// self-listen cycle Riverpod's analyzer flags.
//
// Eagerly read once on app boot — `main_screen.dart` does this in
// `initState`. The provider has no value-shaped output; it exists only for
// its `ref.listen` side effect.
final blockerAutoSchedulerProvider = Provider<void>((ref) {
  ref.listen(prayerTimesProvider.select((s) => s.prayerTimes),
      (prev, next) {
    if (next == null) return;
    if (prev != null && prev == next) return;

    final repo = ref.read(appBlockerRepositoryProvider);
    if (!repo.getAutoBlockingEnabled()) return;

    final scheduler = ref.read(blockerSchedulerProvider);
    scheduler.rescheduleForToday(next).then((count) {
      AppLogger.info('Rescheduled $count blocker window(s) for today');
    }).catchError((Object e) {
      AppLogger.error('Blocker window reschedule failed', e);
    });
  });
});
