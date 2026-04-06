import 'package:flutter/services.dart';

class AppBlockerNativeDataSource {
  static const _channel = MethodChannel('com.mdnahid.prayerlock/app_blocker');

  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    return (result ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> startBlockerService(List<String> packages) async {
    await _channel.invokeMethod<void>(
      'startBlockerService',
      {'packages': packages},
    );
  }

  Future<void> stopBlockerService() async {
    await _channel.invokeMethod<void>('stopBlockerService');
  }

  Future<bool> isBlockerServiceRunning() async {
    return await _channel.invokeMethod<bool>('isBlockerServiceRunning') ?? false;
  }

  Future<bool> hasUsageStatsPermission() async {
    return await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
  }

  Future<bool> hasOverlayPermission() async {
    return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  Future<void> openUsageStatsSettings() async {
    await _channel.invokeMethod<void>('openUsageStatsSettings');
  }

  Future<void> openOverlaySettings() async {
    await _channel.invokeMethod<void>('openOverlaySettings');
  }
}
