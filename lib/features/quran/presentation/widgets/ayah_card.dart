import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/bookmark_button.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/font_size_controls.dart';

/// Translation display filter
enum TranslationFilter {
  english,
  bangla,
  both,
}

/// Controls which translations are shown in the reader
final translationFilterProvider =
    StateProvider<TranslationFilter>((ref) => TranslationFilter.both);

/// Kept for backward-compat — returns true if any translation is shown
final translationVisibilityProvider = Provider<bool>((ref) {
  return true;
});

/// A single Ayah card — theme-aware
class AyahCard extends ConsumerWidget {
  const AyahCard({
    super.key,
    required this.ayah,
    required this.surahName,
    this.onBookmarkToggle,
    this.isBookmarked = false,
  });

  final Ayah ayah;
  final String surahName;
  final VoidCallback? onBookmarkToggle;
  final bool isBookmarked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final filter = ref.watch(translationFilterProvider);
    final arabicFontSize = ref.watch(arabicFontSizeProvider);

    final showEnglish =
        filter == TranslationFilter.english || filter == TranslationFilter.both;
    final showBangla =
        filter == TranslationFilter.bangla || filter == TranslationFilter.both;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Ayah number + bookmark ──────────────────────────────────
            Row(
              children: [
                _AyahNumberBadge(number: ayah.ayahNumber),
                const Spacer(),
                if (onBookmarkToggle != null)
                  BookmarkButton(
                    isBookmarked: isBookmarked,
                    onPressed: onBookmarkToggle!,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // ── Arabic text ─────────────────────────────────────────────
            Text(
              ayah.textArabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: arabicFontSize,
                height: 2.1,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
                letterSpacing: 0.3,
              ),
            ),
            // ── English translation ─────────────────────────────────────
            if (showEnglish && ayah.textEnglish.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              const SizedBox(height: 12),
              _TranslationLabel(
                label: 'English',
                color: cs.primary,
              ),
              const SizedBox(height: 6),
              Text(
                ayah.textEnglish,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
            // ── Bengali translation ─────────────────────────────────────
            if (showBangla && ayah.textBengali.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (!showEnglish || ayah.textEnglish.isEmpty)
                Divider(height: 1, thickness: 1, color: cs.outlineVariant),
              if (!showEnglish || ayah.textEnglish.isEmpty)
                const SizedBox(height: 12),
              _TranslationLabel(
                label: 'বাংলা',
                color: cs.secondary,
              ),
              const SizedBox(height: 6),
              Text(
                ayah.textBengali,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Ayah number badge ──────────────────────────────────────────────────────

class _AyahNumberBadge extends StatelessWidget {
  const _AyahNumberBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: cs.primary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─── Translation language label ────────────────────────────────────────────

class _TranslationLabel extends StatelessWidget {
  const _TranslationLabel({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}
