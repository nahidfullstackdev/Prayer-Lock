import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';

/// Expandable card that displays a single Hadith with Arabic + English text.
class HadithCard extends StatefulWidget {
  const HadithCard({
    required this.hadith,
    required this.index,
    super.key,
  });

  final Hadith hadith;
  final int index;

  @override
  State<HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<HadithCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = widget.hadith;

    final bool hasGrade = h.gradeEn != null && h.gradeEn!.isNotEmpty;
    final Color gradeColor = _gradeColor(h.gradeEn, cs);

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
              // ── Header ──────────────────────────────────────────────────
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
                      h.hadithNumber,
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
                      h.chapterTitle.isNotEmpty
                          ? h.chapterTitle
                          : 'Chapter ${h.bookNumber}',
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
                        h.gradeEn!,
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

              // ── Arabic text ──────────────────────────────────────────────
              Text(
                h.textArabic,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.9,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: _expanded ? null : 3,
                overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),

              // ── English text (only when expanded) ───────────────────────
              if (_expanded) ...[
                const SizedBox(height: 12),
                Divider(color: cs.outlineVariant, height: 1),
                const SizedBox(height: 12),
                Text(
                  h.textEnglish,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: cs.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Actions ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${h.textArabic}\n\n${h.textEnglish}',
                          ),
                        );
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
