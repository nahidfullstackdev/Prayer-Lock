import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for Arabic font size
final arabicFontSizeProvider = StateNotifierProvider<ArabicFontSizeNotifier, double>((ref) {
  return ArabicFontSizeNotifier();
});

/// State notifier for Arabic font size with persistence
class ArabicFontSizeNotifier extends StateNotifier<double> {
  static const String _key = 'arabic_font_size';
  static const double _defaultSize = 24.0;
  static const double _minSize = 18.0;
  static const double _maxSize = 32.0;

  ArabicFontSizeNotifier() : super(_defaultSize) {
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getDouble(_key) ?? _defaultSize;
    } catch (e) {
      state = _defaultSize;
    }
  }

  Future<void> setFontSize(double size) async {
    if (size < _minSize || size > _maxSize) return;

    state = size;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, size);
    } catch (e) {
      // Handle error silently
    }
  }

  void increase() {
    if (state < _maxSize) {
      setFontSize(state + 2);
    }
  }

  void decrease() {
    if (state > _minSize) {
      setFontSize(state - 2);
    }
  }
}

/// Font size controls widget
class FontSizeControls extends ConsumerWidget {
  const FontSizeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(arabicFontSizeProvider);
    final notifier = ref.read(arabicFontSizeProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.text_decrease),
          onPressed: notifier.decrease,
          tooltip: 'Decrease font size',
        ),
        Text(
          '${fontSize.toInt()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.text_increase),
          onPressed: notifier.increase,
          tooltip: 'Increase font size',
        ),
      ],
    );
  }
}
