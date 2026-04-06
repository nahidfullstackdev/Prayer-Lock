import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode provider — dark by default, persisted to SharedPreferences
final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const String _key = 'is_dark_mode';

  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_key) ?? true;
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {
      state = ThemeMode.dark;
    }
  }

  Future<void> toggle() async {
    final nowDark = state == ThemeMode.dark;
    state = nowDark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, !nowDark);
    } catch (_) {
      // persist silently
    }
  }

  bool get isDark => state == ThemeMode.dark;
}
