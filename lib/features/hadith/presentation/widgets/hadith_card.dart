import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_language.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_language_preferences_provider.dart';

/// Expandable card displaying a single Hadith in all user-selected languages.
///
/// Collapsed: shows the first selected language (Arabic if selected) limited
/// to 3 lines. Expanded: shows all selected language texts with labels.
class HadithCard extends ConsumerStatefulWidget {
  const HadithCard({
    required this.hadith,
    required this.index,
    super.key,
  });

  final Hadith hadith;
  final int index;

  @override
  ConsumerState<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends ConsumerState<HadithCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = widget.hadith;
    final selectedLanguages = ref.watch(hadithSelectedLanguagesProvider);

    // Build ordered list of languages that have text for this hadith
    final activeLangs = selectedLanguages
        .where((code) => (h.translations[code] ?? '').isNotEmpty)
        .toList();

    final bool hasGrade = h.grade != null && h.grade!.isNotEmpty;
    final Color gradeColor = _gradeColor(h.grade, cs);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ───────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${h.hadithNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      h.section.isNotEmpty ? h.section : 'Hadith ${h.hadithNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasGrade) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        h.grade!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: gradeColor,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Primary language text (collapsed / first) ─────────────────
              if (activeLangs.isNotEmpty) ...[
                _TranslationBlock(
                  langCode: activeLangs.first,
                  text: h.translations[activeLangs.first]!,
                  collapsed: !_expanded,
                  showLabel: activeLangs.length > 1,
                ),
              ] else ...[
                Text(
                  'No translation available',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],

              // ── Expanded: remaining languages + actions ───────────────────
              if (_expanded && activeLangs.length > 1) ...[
                for (final langCode in activeLangs.skip(1)) ...[
                  const SizedBox(height: 12),
                  Divider(color: cs.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  _TranslationBlock(
                    langCode: langCode,
                    text: h.translations[langCode]!,
                    collapsed: false,
                    showLabel: true,
                  ),
                ],
              ],

              if (_expanded) ...[
                const SizedBox(height: 12),
                // ── Actions ────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: () {
                        final text = activeLangs
                            .map((c) => h.translations[c] ?? '')
                            .where((t) => t.isNotEmpty)
                            .join('\n\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hadith copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _gradeColor(String? grade, ColorScheme cs) {
    if (grade == null) return cs.onSurfaceVariant;
    final lower = grade.toLowerCase();
    if (lower.contains('sahih')) return const Color(0xFF16A34A);
    if (lower.contains('hasan')) return const Color(0xFF2563EB);
    if (lower.contains('da')) return const Color(0xFFDC2626);
    return cs.secondary;
  }
}

// ─── Translation text block ───────────────────────────────────────────────────

class _TranslationBlock extends StatelessWidget {
  const _TranslationBlock({
    required this.langCode,
    required this.text,
    required this.collapsed,
    required this.showLabel,
  });

  final String langCode;
  final String text;
  final bool collapsed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = HadithLanguage.fromCode(langCode);
    final isRtl = lang?.isRtl ?? false;
    final textDirection =
        isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              lang?.name ?? langCode.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cs.secondary.withValues(alpha: 0.7),
                letterSpacing: 0.8,
              ),
            ),
          ),
        Text(
          text,
          textDirection: textDirection,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: isRtl ? 18 : 14,
            height: isRtl ? 1.9 : 1.6,
            color: isRtl
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.85),
            fontWeight: isRtl ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: collapsed ? 3 : null,
          overflow:
              collapsed ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
      ],
    );
  }
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pro locked card ──────────────────────────────────────────────────────────

/// Paywall teaser card shown after the free hadith limit.
class HadithProLockedCard extends StatelessWidget {
  const HadithProLockedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_rounded, color: cs.secondary, size: 32),
          const SizedBox(height: 10),
          Text(
            'Unlock Full Hadith Collections',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Browse thousands of authenticated hadiths with '
            'infinite scroll — available with Prayer Lock Pro.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              // TODO: trigger RevenueCat paywall
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Upgrade to Pro'),
          ),
        ],
      ),
    );
  }
}
