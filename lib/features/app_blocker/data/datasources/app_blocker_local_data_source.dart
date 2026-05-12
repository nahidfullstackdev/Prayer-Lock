import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// Hive-backed local cache for the App Blocker.
///
/// Box: `app_blocker` (opened during critical init in AppInitializer).
class AppBlockerLocalDataSource {
  static const _boxName = 'app_blocker';
  static const _keyBlockedPackages = 'blocked_packages';
  static const _keyHasAccessibility = 'has_accessibility';
  static const _keyHasOverlay = 'has_overlay';
  static const _keyWindowMinutes = 'window_minutes';
  static const _keyAutoBlockingEnabled = 'auto_blocking_enabled';

  /// Default duration of each prayer window, in minutes.
  static const int _defaultWindowMinutes = 20;

  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  // ── Blocked packages ───────────────────────────────────────────────────────

  Future<List<String>> getBlockedPackages() async {
    try {
      final raw = _box.get(_keyBlockedPackages);
      if (raw == null) return [];
      return (raw as List<dynamic>).cast<String>();
    } catch (e) {
      AppLogger.warning('Failed to read blocked packages from Hive: $e');
      return [];
    }
  }

  Future<void> saveBlockedPackages(List<String> packages) async {
    await _box.put(_keyBlockedPackages, packages);
    AppLogger.debug('Saved ${packages.length} blocked package(s) to Hive');
  }

  // ── Permission cache ───────────────────────────────────────────────────────

  /// Returns the last-known permission state stored in Hive.
  /// Both default to false (safe default) when never written.
  ({bool hasAccessibility, bool hasOverlay}) getCachedPermissions() {
    return (
      hasAccessibility:
          (_box.get(_keyHasAccessibility, defaultValue: false) as bool?) ??
              false,
      hasOverlay:
          (_box.get(_keyHasOverlay, defaultValue: false) as bool?) ?? false,
    );
  }

  Future<void> savePermissions({
    required bool hasAccessibility,
    required bool hasOverlay,
  }) async {
    await _box.put(_keyHasAccessibility, hasAccessibility);
    await _box.put(_keyHasOverlay, hasOverlay);
    AppLogger.debug(
      'Saved permissions to Hive — accessibility: $hasAccessibility, overlay: $hasOverlay',
    );
  }

  // ── Auto-blocking master switch ────────────────────────────────────────────

  bool getAutoBlockingEnabled() {
    return (_box.get(_keyAutoBlockingEnabled, defaultValue: false) as bool?) ??
        false;
  }

  Future<void> saveAutoBlockingEnabled(bool enabled) async {
    await _box.put(_keyAutoBlockingEnabled, enabled);
  }

  // ── Window duration (user-configurable later) ─────────────────────────────

  int getWindowMinutes() {
    final v = _box.get(_keyWindowMinutes, defaultValue: _defaultWindowMinutes);
    if (v is int) return v;
    return _defaultWindowMinutes;
  }

  Future<void> saveWindowMinutes(int minutes) async {
    await _box.put(_keyWindowMinutes, minutes);
  }
}
