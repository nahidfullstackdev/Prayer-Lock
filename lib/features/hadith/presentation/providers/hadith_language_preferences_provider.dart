import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the user's selected hadith display languages.
///
/// Default: Arabic + English. Persisted to SharedPreferences.
class HadithLanguagesNotifier extends StateNotifier<List<String>> {
  HadithLanguagesNotifier() : super(HadithLanguage.defaultSelected) {
    _loadFromPrefs();
  }

  static const _prefsKey = 'hadith_selected_languages';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        state = saved;
      }
    } catch (e) {
      AppLogger.warning('Could not load hadith language prefs: $e');
    }
  }

  /// Toggles [langCode] in the selected list.
  /// Requires at least one language to always remain selected.
  Future<void> toggle(String langCode) async {
    List<String> updated;
    if (state.contains(langCode)) {
      if (state.length == 1) return; // Always keep at least one
      updated = state.where((l) => l != langCode).toList();
    } else {
      updated = [...state, langCode];
    }
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, updated);
    } catch (e) {
      AppLogger.warning('Could not save hadith language prefs: $e');
    }
  }
}

/// Provider for the user's currently selected hadith display languages.
/// Default is ['ara', 'eng']. Persisted across app restarts.
final hadithSelectedLanguagesProvider =
    StateNotifierProvider<HadithLanguagesNotifier, List<String>>(
  (ref) => HadithLanguagesNotifier(),
);
