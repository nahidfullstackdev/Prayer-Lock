import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/ayah_card.dart';

/// Toggle button to cycle through translation filters
class TranslationToggle extends ConsumerWidget {
  const TranslationToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(translationFilterProvider);

    final icon = switch (filter) {
      TranslationFilter.english => Icons.translate_rounded,
      TranslationFilter.bangla => Icons.translate_rounded,
      TranslationFilter.both => Icons.translate_rounded,
    };

    final tooltip = switch (filter) {
      TranslationFilter.english => 'English — tap for Bangla',
      TranslationFilter.bangla => 'Bangla — tap for Both',
      TranslationFilter.both => 'Both — tap for English',
    };

    return IconButton(
      icon: Icon(icon),
      onPressed: () {
        final next = switch (filter) {
          TranslationFilter.both => TranslationFilter.english,
          TranslationFilter.english => TranslationFilter.bangla,
          TranslationFilter.bangla => TranslationFilter.both,
        };
        ref.read(translationFilterProvider.notifier).state = next;
      },
      tooltip: tooltip,
    );
  }
}
