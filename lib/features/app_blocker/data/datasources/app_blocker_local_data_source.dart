import 'dart:convert';

import 'package:prayer_lock/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppBlockerLocalDataSource {
  static const _key = 'app_blocker_blocked_packages';

  Future<List<String>> getBlockedPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<String>();
    } catch (e) {
      AppLogger.warning('Failed to read blocked packages: $e');
      return [];
    }
  }

  Future<void> saveBlockedPackages(List<String> packages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(packages));
  }
}
