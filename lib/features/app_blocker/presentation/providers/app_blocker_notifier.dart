import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_installed_apps.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/save_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/start_blocker_service.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/stop_blocker_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AppBlockerState {
  const AppBlockerState({
    this.installedApps = const [],
    this.blockedPackages = const {},
    this.isServiceRunning = false,
    this.hasUsageStatsPermission = false,
    this.hasOverlayPermission = false,
    this.isLoadingApps = false,
    this.isTogglingService = false,
    this.errorMessage,
  });

  final List<BlockedApp> installedApps;
  final Set<String> blockedPackages;
  final bool isServiceRunning;
  final bool hasUsageStatsPermission;
  final bool hasOverlayPermission;
  final bool isLoadingApps;
  final bool isTogglingService;
  final String? errorMessage;

  bool get hasAllPermissions =>
      hasUsageStatsPermission && hasOverlayPermission;

  AppBlockerState copyWith({
    List<BlockedApp>? installedApps,
    Set<String>? blockedPackages,
    bool? isServiceRunning,
    bool? hasUsageStatsPermission,
    bool? hasOverlayPermission,
    bool? isLoadingApps,
    bool? isTogglingService,
    String? errorMessage,
  }) {
    return AppBlockerState(
      installedApps: installedApps ?? this.installedApps,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      isServiceRunning: isServiceRunning ?? this.isServiceRunning,
      hasUsageStatsPermission:
          hasUsageStatsPermission ?? this.hasUsageStatsPermission,
      hasOverlayPermission: hasOverlayPermission ?? this.hasOverlayPermission,
      isLoadingApps: isLoadingApps ?? this.isLoadingApps,
      isTogglingService: isTogglingService ?? this.isTogglingService,
      errorMessage: errorMessage,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AppBlockerNotifier extends StateNotifier<AppBlockerState> {
  AppBlockerNotifier({
    required this.getInstalledAppsUseCase,
    required this.getBlockedPackagesUseCase,
    required this.saveBlockedPackagesUseCase,
    required this.startBlockerServiceUseCase,
    required this.stopBlockerServiceUseCase,
    required this.repository,
  }) : super(const AppBlockerState());

  final GetInstalledAppsUseCase getInstalledAppsUseCase;
  final GetBlockedPackagesUseCase getBlockedPackagesUseCase;
  final SaveBlockedPackagesUseCase saveBlockedPackagesUseCase;
  final StartBlockerServiceUseCase startBlockerServiceUseCase;
  final StopBlockerServiceUseCase stopBlockerServiceUseCase;
  final AppBlockerRepository repository;

  Timer? _debounceTimer;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Called once on screen open. Loads saved packages, checks permissions,
  /// then fetches the installed apps list (the slow native call).
  Future<void> initialize() async {
    if (state.isLoadingApps) return;

    // Fast: load saved packages and check permissions/service status
    final packagesResult = await getBlockedPackagesUseCase();
    final packages = packagesResult.fold((_) => <String>[], (l) => l);

    await _updatePermissionsAndServiceState(packages.toSet());

    // Slow: fetch installed apps from native side
    state = state.copyWith(isLoadingApps: true, errorMessage: null);
    final appsResult = await getInstalledAppsUseCase();
    appsResult.fold(
      (failure) {
        AppLogger.error('Failed to load installed apps: ${failure.message}');
        state = state.copyWith(
          isLoadingApps: false,
          errorMessage: failure.message,
        );
      },
      (apps) {
        AppLogger.info('Loaded ${apps.length} installed apps');
        state = state.copyWith(installedApps: apps, isLoadingApps: false);
      },
    );
  }

  /// Re-checks permissions only — called when returning from Android Settings.
  Future<void> refreshPermissions() async {
    await _updatePermissionsAndServiceState(state.blockedPackages);
  }

  Future<void> _updatePermissionsAndServiceState(Set<String> packages) async {
    final usageResult = await repository.hasUsageStatsPermission();
    final overlayResult = await repository.hasOverlayPermission();
    final serviceResult = await repository.isBlockerServiceRunning();

    state = state.copyWith(
      blockedPackages: packages,
      hasUsageStatsPermission: usageResult.fold((_) => false, (v) => v),
      hasOverlayPermission: overlayResult.fold((_) => false, (v) => v),
      isServiceRunning: serviceResult.fold((_) => false, (v) => v),
      errorMessage: null,
    );
  }

  // ── App selection ────────────────────────────────────────────────────────

  /// Toggles a single app's blocked status. Auto-saves to SharedPreferences
  /// and restarts the service (if running) after a 500 ms debounce.
  void toggleApp(String packageName) {
    final updated = Set<String>.from(state.blockedPackages);
    if (updated.contains(packageName)) {
      updated.remove(packageName);
    } else {
      updated.add(packageName);
    }
    state = state.copyWith(blockedPackages: updated, errorMessage: null);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _persistAndApply(updated);
    });
  }

  Future<void> _persistAndApply(Set<String> packages) async {
    await saveBlockedPackagesUseCase(packages.toList());

    if (state.isServiceRunning) {
      // Restart service so it picks up the updated package list immediately.
      await repository.stopBlockerService();
      if (packages.isNotEmpty) {
        await repository.startBlockerService(packages.toList());
      } else {
        state = state.copyWith(isServiceRunning: false);
      }
    }
  }

  // ── Service toggle ───────────────────────────────────────────────────────

  Future<void> toggleService({required bool enable}) async {
    if (enable) {
      if (!state.hasUsageStatsPermission || !state.hasOverlayPermission) {
        state = state.copyWith(
          errorMessage: 'Grant both permissions before enabling the blocker.',
        );
        return;
      }
      if (state.blockedPackages.isEmpty) {
        state = state.copyWith(
          errorMessage: 'Select at least one app to block first.',
        );
        return;
      }

      state = state.copyWith(isTogglingService: true, errorMessage: null);
      final result = await startBlockerServiceUseCase(
        state.blockedPackages.toList(),
      );
      result.fold(
        (failure) => state = state.copyWith(
          isTogglingService: false,
          errorMessage: failure.message,
        ),
        (_) => state = state.copyWith(
          isTogglingService: false,
          isServiceRunning: true,
        ),
      );
    } else {
      state = state.copyWith(isTogglingService: true);
      await stopBlockerServiceUseCase();
      state = state.copyWith(
        isTogglingService: false,
        isServiceRunning: false,
        errorMessage: null,
      );
    }
  }

  // ── Permission navigation ────────────────────────────────────────────────

  Future<void> openUsageStatsSettings() =>
      repository.openUsageStatsSettings();

  Future<void> openOverlaySettings() => repository.openOverlaySettings();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
