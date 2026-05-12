import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocker_window.dart';

/// Public surface of the App Blocker repository.
///
/// Detection is event-driven via the native Accessibility Service; this
/// interface exposes only the configuration + scheduling methods Flutter
/// needs. There is no "service running" concept anymore — the Accessibility
/// Service is bound by the OS as long as the user has it enabled.
abstract class AppBlockerRepository {
  // ── Installed apps + selection persistence ──────────────────────────────
  Future<Either<Failure, List<BlockedApp>>> getInstalledApps();
  Future<Either<Failure, List<String>>> getBlockedPackages();
  Future<Either<Failure, Unit>> saveBlockedPackages(List<String> packages);

  /// Pushes the package list to the native side so the Accessibility Service
  /// reads the up-to-date set on every event.
  Future<Either<Failure, Unit>> pushBlockedPackagesToNative(
    List<String> packages,
  );

  // ── Permissions ─────────────────────────────────────────────────────────
  Future<Either<Failure, bool>> hasAccessibilityPermission();
  Future<Either<Failure, bool>> hasOverlayPermission();
  Future<Either<Failure, Unit>> openAccessibilitySettings();
  Future<Either<Failure, Unit>> openOverlaySettings();

  /// Returns the last-known permission state persisted to Hive.
  /// Used for instant UI on screen open, before native checks complete.
  Either<Failure, ({bool hasAccessibility, bool hasOverlay})>
      getCachedPermissions();

  /// Persists the current permission state to Hive after a native check.
  Future<Either<Failure, Unit>> savePermissions({
    required bool hasAccessibility,
    required bool hasOverlay,
  });

  // ── Auto-blocking master switch ─────────────────────────────────────────

  /// Enables or disables auto-blocking during prayer windows. Persists to
  /// both Hive and the native SharedPreferences the Accessibility Service
  /// reads from.
  Future<Either<Failure, Unit>> setAutoBlockingEnabled(bool enabled);

  bool getAutoBlockingEnabled();

  // ── Window scheduling ───────────────────────────────────────────────────

  /// Replaces all currently-scheduled window alarms with [windows].
  Future<Either<Failure, Unit>> scheduleBlockerWindows(
    List<BlockerWindow> windows,
  );

  Future<Either<Failure, Unit>> cancelAllBlockerWindows();

  /// Default window length in minutes (currently 20, user-configurable
  /// surface comes later).
  int getWindowMinutes();
}
