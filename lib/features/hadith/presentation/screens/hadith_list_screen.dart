import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_language.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:prayer_lock/features/hadith/presentation/widgets/hadith_card.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:prayer_lock/features/subscription/presentation/widgets/pro_paywall_sheet.dart';

/// Displays hadiths for a single collection with search, language filter,
/// and infinite scroll (Pro).
class HadithListScreen extends ConsumerStatefulWidget {
  const HadithListScreen({required this.collection, super.key});

  final HadithCollection collection;

  @override
  ConsumerState<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends ConsumerState<HadithListScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(hadithListProvider(widget.collection.name).notifier)
          .loadFirstPage();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Free users are capped at the first page — no infinite scroll.
    if (!ref.read(isProProvider)) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref
          .read(hadithListProvider(widget.collection.name).notifier)
          .loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(hadithListProvider(widget.collection.name));
    final selectedLanguages = ref.watch(hadithSelectedLanguagesProvider);
    final isPro = ref.watch(isProProvider);

    final rawList =
        state.isInSearchMode ? state.searchResults : state.hadiths;
    // Free tier: cap visible hadiths at hadithFreePageSize. Search results
    // stay unfiltered so users can discover what's behind Pro before paying.
    final displayList = (!isPro && !state.isInSearchMode)
        ? rawList.take(ApiConstants.hadithFreePageSize).toList()
        : rawList;
    final showFreeCap = !isPro &&
        !state.isInSearchMode &&
        rawList.length >= ApiConstants.hadithFreePageSize;

    // Available languages for this collection (filter to known ones)
    final availableLangs = widget.collection.availableLanguages.isNotEmpty
        ? widget.collection.availableLanguages
            .map(HadithLanguage.fromCode)
            .whereType<HadithLanguage>()
            .toList()
        : HadithLanguage.allLanguages;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      cs.secondary.withValues(alpha: 0.15),
                      cs.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.collection.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${widget.collection.totalHadith} Hadiths',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                  color: cs.onSurface,
                ),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchController.clear();
                    ref
                        .read(
                          hadithListProvider(widget.collection.name).notifier,
                        )
                        .clearSearch();
                  }
                },
              ),
            ],
          ),

          // ── Search bar ───────────────────────────────────────────────────
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search hadiths…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(
                                    hadithListProvider(widget.collection.name)
                                        .notifier,
                                  )
                                  .clearSearch();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (q) => ref
                      .read(hadithListProvider(widget.collection.name).notifier)
                      .search(q),
                ),
              ),
            ),

          // ── Language filter chips ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _LanguageFilterRow(
              availableLanguages: availableLangs,
              selectedLanguages: selectedLanguages,
              onToggle: (code) => ref
                  .read(hadithSelectedLanguagesProvider.notifier)
                  .toggle(code),
            ),
          ),

          // ── Loading state ────────────────────────────────────────────────
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )

          // ── Error state ──────────────────────────────────────────────────
          else if (state.errorMessage != null && displayList.isEmpty)
            SliverFillRemaining(
              child: _ErrorView(
                message: state.errorMessage!,
                onRetry: () => ref
                    .read(hadithListProvider(widget.collection.name).notifier)
                    .loadFirstPage(),
              ),
            )

          // ── Searching spinner ────────────────────────────────────────────
          else if (state.isInSearchMode && state.isSearching)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )

          // ── Empty search results ─────────────────────────────────────────
          else if (state.isInSearchMode && state.searchResults.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No results for "${state.searchQuery}"',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )

          // ── Hadith list ──────────────────────────────────────────────────
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverList.builder(
                itemCount: displayList.length,
                itemBuilder: (context, index) => HadithCard(
                  hadith: displayList[index],
                  index: index + 1,
                ),
              ),
            ),

            // Load more indicator (Pro only — free users are capped)
            if (state.isLoadingMore && isPro)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // Free-tier paywall CTA — replaces pagination after the cap
            if (showFreeCap)
              SliverToBoxAdapter(
                child: _FreeCapCta(
                  collectionTitle: widget.collection.title,
                  totalHadith: widget.collection.totalHadith,
                  freeLimit: ApiConstants.hadithFreePageSize,
                  onUnlock: () => showProPaywall(
                    context,
                    ref.read(subscriptionRepositoryProvider),
                    placement: 'hadith_locked',
                    featureTitle: 'Hadith Collections',
                    featureDescription:
                        'Unlock the full ${widget.collection.title} and every other collection.',
                  ),
                ),
              ),

            // End-of-list (Pro only)
            if (isPro && !state.hasMore && displayList.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'All ${widget.collection.totalHadith} hadiths loaded',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ],
      ),
    );
  }
}

// ─── Language filter row ──────────────────────────────────────────────────────

class _LanguageFilterRow extends StatelessWidget {
  const _LanguageFilterRow({
    required this.availableLanguages,
    required this.selectedLanguages,
    required this.onToggle,
  });

  final List<HadithLanguage> availableLanguages;
  final List<String> selectedLanguages;
  final void Function(String code) onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Languages:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ...availableLanguages.map((lang) {
              final selected = selectedLanguages.contains(lang.code);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onToggle(lang.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.secondary
                          : cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? cs.secondary
                            : cs.outlineVariant,
                      ),
                    ),
                    child: Text(
                      lang.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? cs.onSecondary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Free-tier paywall CTA ────────────────────────────────────────────────────

class _FreeCapCta extends StatelessWidget {
  const _FreeCapCta({
    required this.collectionTitle,
    required this.totalHadith,
    required this.freeLimit,
    required this.onUnlock,
  });

  final String collectionTitle;
  final int totalHadith;
  final int freeLimit;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = cs.secondary;
    final remaining = totalHadith - freeLimit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gold.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    gold.withValues(alpha: 0.28),
                    gold.withValues(alpha: 0.05),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: gold.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.workspace_premium_rounded, color: gold, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve read the free preview',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$remaining more hadiths in $collectionTitle are reserved for Pro members.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: onUnlock,
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor:
                      isDark ? const Color(0xFF1A1A00) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Unlock all Hadith collections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
