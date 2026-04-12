import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/utils/logger.dart';

class AppBlockerLocalDataSource {
  static const _boxName = 'app_blocker';
  static const _keyBlockedPackages = 'blocked_packages';
  static const _keyHasUsageStats = 'has_usage_stats';
  static const _keyHasOverlay = 'has_overlay';

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
  ({bool hasUsageStats, bool hasOverlay}) getCachedPermissions() {
    return (
      hasUsageStats:
          (_box.get(_keyHasUsageStats, defaultValue: false) as bool?) ?? false,
      hasOverlay:
          (_box.get(_keyHasOverlay, defaultValue: false) as bool?) ?? false,
    );
  }

  Future<void> savePermissions({
    required bool hasUsageStats,
    required bool hasOverlay,
  }) async {
    await _box.put(_keyHasUsageStats, hasUsageStats);
    await _box.put(_keyHasOverlay, hasOverlay);
    AppLogger.debug(
      'Saved permissions to Hive — usageStats: $hasUsageStats, overlay: $hasOverlay',
    );
  }
}
