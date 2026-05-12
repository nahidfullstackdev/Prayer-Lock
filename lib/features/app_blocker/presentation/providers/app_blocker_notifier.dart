import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/app_blocker/data/services/blocker_scheduler.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/domain/repositories/app_blocker_repository.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_blocked_packages.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/get_installed_apps.dart';
import 'package:prayer_lock/features/app_blocker/domain/usecases/save_blocked_packages.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AppBlockerState {
  const AppBlockerState({
    this.installedApps = const [],
    this.blockedPackages = const {},
    this.isAutoBlockingEnabled = false,
    this.hasAccessibilityPermission = false,
    this.hasOverlayPermission = false,
    this.isLoadingApps = false,
    this.isTogglingService = false,
    this.errorMessage,
  });

  final List<BlockedApp> installedApps;
  final Set<String> blockedPackages;

  /// Master switch — when true, the Accessibility Service is armed during
  /// scheduled prayer windows.
  final bool isAutoBlockingEnabled;

  final bool hasAccessibilityPermission;
  final bool hasOverlayPermission;
  final bool isLoadingApps;
  final bool isTogglingService;
  final String? errorMessage;

  bool get hasAllPermissions =>
      hasAccessibilityPermission && hasOverlayPermission;

  AppBlockerState copyWith({
    List<BlockedApp>? installedApps,
    Set<String>? blockedPackages,
    bool? isAutoBlockingEnabled,
    bool? hasAccessibilityPermission,
    bool? hasOverlayPermission,
    bool? isLoadingApps,
    bool? isTogglingService,
    String? errorMessage,
  }) {
    return AppBlockerState(
      installedApps: installedApps ?? this.installedApps,
      blockedPackages: blockedPackages ?? this.blockedPackages,
      isAutoBlockingEnabled:
          isAutoBlockingEnabled ?? this.isAutoBlockingEnabled,
      hasAccessibilityPermission:
          hasAccessibilityPermission ?? this.hasAccessibilityPermission,
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
    required this.repository,
    required this.scheduler,
  }) : super(const AppBlockerState());

  final GetInstalledAppsUseCase getInstalledAppsUseCase;
  final GetBlockedPackagesUseCase getBlockedPackagesUseCase;
  final SaveBlockedPackagesUseCase saveBlockedPackagesUseCase;
  final AppBlockerRepository repository;
  final BlockerScheduler scheduler;

  Timer? _debounceTimer;

  // ── Initialization ───────────────────────────────────────────────────────

  /// Called once on screen open. Loads saved packages, checks permissions,
  /// then fetches the installed apps list (the slow native call).
  Future<void> initialize() async {
    if (state.isLoadingApps) return;

    // Instant: apply Hive-cached permissions so the UI is responsive immediately,
    // before the async native checks complete.
    final cached = repository.getCachedPermissions();
    cached.fold(
      (_) {},
      (perms) => state = state.copyWith(
        hasAccessibilityPermission: perms.hasAccessibility,
        hasOverlayPermission: perms.hasOverlay,
      ),
    );

    // Fast: load saved blocked packages from Hive
    final packagesResult = await getBlockedPackagesUseCase();
    final packages = packagesResult.fold((_) => <String>[], (l) => l);

    // Authoritative: verify permissions + auto-blocking state from native side
    // and persist back to Hive.
    await _refreshFromNative(packages.toSet());

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
    await _refreshFromNative(state.blockedPackages);
  }

  Future<void> _refreshFromNative(Set<String> packages) async {
    final accessibilityResult = await repository.hasAccessibilityPermission();
    final overlayResult = await repository.hasOverlayPermission();

    final hasAccessibility = accessibilityResult.fold((_) => false, (v) => v);
    final hasOverlay = overlayResult.fold((_) => false, (v) => v);
    final autoEnabled = repository.getAutoBlockingEnabled();

    state = state.copyWith(
      blockedPackages: packages,
      hasAccessibilityPermission: hasAccessibility,
      hasOverlayPermission: hasOverlay,
      isAutoBlockingEnabled: autoEnabled,
      errorMessage: null,
    );

    await repository.savePermissions(
      hasAccessibility: hasAccessibility,
      hasOverlay: hasOverlay,
    );
  }

  // ── App selection ────────────────────────────────────────────────────────

  /// Toggles a single app's blocked status. Auto-saves to Hive and pushes
  /// the updated set to the Accessibility Service after a 500ms debounce.
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
      _persistAndPush(updated);
    });
  }

  Future<void> _persistAndPush(Set<String> packages) async {
    await saveBlockedPackagesUseCase(packages.toList());
    await repository.pushBlockedPackagesToNative(packages.toList());
  }

  // ── Auto-blocking master switch ──────────────────────────────────────────

  /// Enables or disables auto-blocking during prayer windows. On enable:
  /// validates permissions + non-empty selection, pushes state to native,
  /// then schedules today's window alarms (if [prayerTimes] is supplied).
  ///
  /// [prayerTimes] is optional — if null, the master switch is still flipped
  /// on, and the listener on `prayerTimesProvider` will schedule windows
  /// once prayer times finish loading.
  Future<void> toggleAutoBlocking({
    required bool enable,
    PrayerTimes? prayerTimes,
  }) async {
    if (enable) {
      if (!state.hasAccessibilityPermission || !state.hasOverlayPermission) {
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

      final setResult = await repository.setAutoBlockingEnabled(true);
      final pushResult = await repository.pushBlockedPackagesToNative(
        state.blockedPackages.toList(),
      );

      final firstFailure = setResult.fold((f) => f, (_) => null) ??
          pushResult.fold((f) => f, (_) => null);
      if (firstFailure != null) {
        state = state.copyWith(
          isTogglingService: false,
          errorMessage: firstFailure.message,
        );
        return;
      }

      if (prayerTimes != null) {
        await scheduler.rescheduleForToday(prayerTimes);
      } else {
        AppLogger.warning(
          'Auto-blocking enabled before prayer times loaded — '
          'scheduling will run on next prayer-times load',
        );
      }

      state = state.copyWith(
        isTogglingService: false,
        isAutoBlockingEnabled: true,
      );
    } else {
      state = state.copyWith(isTogglingService: true);
      await repository.setAutoBlockingEnabled(false);
      await scheduler.cancelAll();
      state = state.copyWith(
        isTogglingService: false,
        isAutoBlockingEnabled: false,
        errorMessage: null,
      );
    }
  }

  // ── Permission navigation ────────────────────────────────────────────────

  Future<void> openAccessibilitySettings() =>
      repository.openAccessibilitySettings();

  Future<void> openOverlaySettings() => repository.openOverlaySettings();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
