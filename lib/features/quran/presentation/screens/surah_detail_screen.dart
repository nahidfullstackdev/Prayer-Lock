import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';
import 'package:prayer_lock/features/quran/presentation/providers/quran_providers.dart';
import 'package:prayer_lock/features/quran/presentation/providers/surah_detail_notifier.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/ayah_card.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/font_size_controls.dart';

/// Screen displaying Ayahs for a specific Surah
class SurahDetailScreen extends ConsumerStatefulWidget {
  const SurahDetailScreen({
    super.key,
    required this.surahId,
    required this.surahName,
    this.initialAyahId,
  });

  final int surahId;
  final String surahName;
  final int? initialAyahId;

  @override
  ConsumerState<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends ConsumerState<SurahDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _didScrollToInitial = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final surahState = ref.read(surahDetailProvider(widget.surahId));
    if (surahState.ayahs.isEmpty || surahState.isLoading) return;
    final index = (_scrollController.offset / 220)
        .floor()
        .clamp(0, surahState.ayahs.length - 1);
    final ayah = surahState.ayahs[index];
    ref
        .read(surahDetailProvider(widget.surahId).notifier)
        .saveLastReadPosition(ayah.id, widget.surahName, ayah.ayahNumber);
  }

  void _scrollToInitialAyah(List<dynamic> ayahs) {
    if (_didScrollToInitial || widget.initialAyahId == null) return;
    _didScrollToInitial = true;
    final index = ayahs.indexWhere((a) => a.id == widget.initialAyahId);
    if (index <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          index * 220.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showFontSizeSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FontSizeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surahState = ref.watch(surahDetailProvider(widget.surahId));
    final bookmarkState = ref.watch(bookmarksProvider);
    final translationFilter = ref.watch(translationFilterProvider);

    ref.listen<SurahDetailState>(
      surahDetailProvider(widget.surahId),
      (prev, next) {
        if (prev?.isLoading == true &&
            !next.isLoading &&
            next.ayahs.isNotEmpty) {
          _scrollToInitialAyah(next.ayahs);
        }
      },
    );

    // AppBar gradient
    final gradientColors = isDark
        ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
        : [const Color(0xFF15803D), const Color(0xFF166534)];

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: gradientColors.last,
            foregroundColor: Colors.white,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradientColors,
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 14),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.surahName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (surahState.ayahs.isNotEmpty)
                    Text(
                      '${surahState.ayahs.length} Ayahs',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              _TranslationFilterButton(
                filter: translationFilter,
                onChanged: (f) {
                  ref.read(translationFilterProvider.notifier).state = f;
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.text_fields_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Font size',
                onPressed: _showFontSizeSheet,
              ),
            ],
          ),

          // ── Loading / Error / Empty ───────────────────────────────────
          if (surahState.isLoading && surahState.ayahs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (surahState.errorMessage != null &&
              surahState.ayahs.isEmpty)
            SliverFillRemaining(
              child: _buildErrorState(cs, surahState.errorMessage!),
            )
          else if (surahState.ayahs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No Ayahs found',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            // ── Bismillah ─────────────────────────────────────────────
            if (widget.surahId != 1 && widget.surahId != 9)
              SliverToBoxAdapter(
                child: _BismillahHeader(colorScheme: cs),
              ),

            // ── Ayah list ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.builder(
                itemCount: surahState.ayahs.length,
                itemBuilder: (context, index) {
                  final ayah = surahState.ayahs[index];
                  final isBookmarked = bookmarkState.bookmarks.any(
                    (b) =>
                        b.surahId == widget.surahId && b.ayahId == ayah.id,
                  );
                  return AyahCard(
                    ayah: ayah,
                    surahName: widget.surahName,
                    isBookmarked: isBookmarked,
                    onBookmarkToggle: () async {
                      final bookmark = Bookmark(
                        surahId: widget.surahId,
                        ayahId: ayah.id,
                        surahName: widget.surahName,
                        ayahNumber: ayah.ayahNumber,
                        createdAt: DateTime.now(),
                      );
                      final success = await ref
                          .read(bookmarksProvider.notifier)
                          .toggleBookmark(bookmark);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isBookmarked
                                  ? 'Bookmark removed'
                                  : 'Bookmark added',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => ref
                  .read(surahDetailProvider(widget.surahId).notifier)
                  .refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Translation Filter Button ─────────────────────────────────────────────

class _TranslationFilterButton extends StatelessWidget {
  const _TranslationFilterButton({
    required this.filter,
    required this.onChanged,
  });

  final TranslationFilter filter;
  final ValueChanged<TranslationFilter> onChanged;

  String get _label {
    switch (filter) {
      case TranslationFilter.english:
        return 'EN';
      case TranslationFilter.bangla:
        return 'BN';
      case TranslationFilter.both:
        return 'ALL';
    }
  }

  TranslationFilter get _next {
    switch (filter) {
      case TranslationFilter.both:
        return TranslationFilter.english;
      case TranslationFilter.english:
        return TranslationFilter.bangla;
      case TranslationFilter.bangla:
        return TranslationFilter.both;
    }
  }

  String get _tooltip {
    switch (filter) {
      case TranslationFilter.english:
        return 'Showing English — tap for Bangla';
      case TranslationFilter.bangla:
        return 'Showing Bangla — tap for Both';
      case TranslationFilter.both:
        return 'Showing Both — tap for English only';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: InkWell(
        onTap: () => onChanged(_next),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.translate_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                _label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bismillah Header ───────────────────────────────────────────────────────

class _BismillahHeader extends StatelessWidget {
  const _BismillahHeader({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Decorative gold line
          Container(
            width: 48,
            height: 2,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          Text(
            'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              height: 1.8,
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 48,
            height: 2,
            margin: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              color: colorScheme.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Font Size Bottom Sheet ─────────────────────────────────────────────────

class _FontSizeSheet extends ConsumerWidget {
  const _FontSizeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final fontSize = ref.watch(arabicFontSizeProvider);
    final notifier = ref.read(arabicFontSizeProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Arabic Font Size',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          // Arabic preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                height: 2.0,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Size controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SizeButton(
                icon: Icons.remove,
                onPressed: notifier.decrease,
                enabled: fontSize > 18,
              ),
              const SizedBox(width: 24),
              Text(
                '${fontSize.toInt()}px',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(width: 24),
              _SizeButton(
                icon: Icons.add,
                onPressed: notifier.increase,
                enabled: fontSize < 32,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? cs.primary : cs.outlineVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : cs.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
