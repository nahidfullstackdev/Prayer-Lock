import 'package:flutter/services.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocker_window.dart';

/// MethodChannel wrapper for the App Blocker native side.
///
/// Channel: com.mdnahid.prayerlock/app_blocker
class AppBlockerNativeDataSource {
  static const _channel = MethodChannel('com.mdnahid.prayerlock/app_blocker');

  // ── Installed apps (launcher intent only — no QUERY_ALL_PACKAGES) ─────────

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (result ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── Permissions ────────────────────────────────────────────────────────────

  Future<bool> hasAccessibilityPermission() async {
    return await _channel.invokeMethod<bool>('hasAccessibilityPermission') ??
        false;
  }

  Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  Future<void> openOverlaySettings() async {
    await _channel.invokeMethod<void>('openOverlaySettings');
  }

  // ── Blocker state (consumed by the Accessibility Service) ─────────────────

  Future<void> setBlockedPackages(List<String> packages) async {
    await _channel.invokeMethod<void>(
      'setBlockedPackages',
      {'packages': packages},
    );
  }

  Future<void> setAutoBlockingEnabled(bool enabled) async {
    await _channel.invokeMethod<void>(
      'setAutoBlockingEnabled',
      {'enabled': enabled},
    );
  }

  Future<bool> isAutoBlockingEnabled() async {
    return await _channel.invokeMethod<bool>('isAutoBlockingEnabled') ?? false;
  }

  // ── Window scheduling (AlarmManager on the native side) ───────────────────

  Future<void> scheduleBlockerWindows(List<BlockerWindow> windows) async {
    await _channel.invokeMethod<void>(
      'scheduleBlockerWindows',
      {'windows': windows.map((w) => w.toMap()).toList()},
    );
  }

  Future<void> cancelAllBlockerWindows() async {
    await _channel.invokeMethod<void>('cancelAllBlockerWindows');
  }
}
