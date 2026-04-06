import 'package:flutter/material.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';

/// Surah list row — theme-aware
class SurahCard extends StatelessWidget {
  const SurahCard({
    super.key,
    required this.surah,
    required this.onTap,
  });

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _NumberBadge(number: surah.id),
            const SizedBox(width: 14),
            Expanded(child: _NameColumn(surah: surah)),
            const SizedBox(width: 10),
            _ArabicColumn(surah: surah),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cs.primary,
          ),
        ),
      ),
    );
  }
}

class _NameColumn extends StatelessWidget {
  const _NameColumn({required this.surah});
  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          surah.nameTransliteration,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${surah.revelationPlace} • ${surah.totalAyahs} verses',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ArabicColumn extends StatelessWidget {
  const _ArabicColumn({required this.surah});
  final Surah surah;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          surah.nameArabic,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.secondary,
          ),
        ),
        if (surah.nameEnglish.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            surah.nameEnglish,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }
}
