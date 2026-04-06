import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:prayer_lock/features/hadith/presentation/widgets/hadith_card.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';

/// Displays hadiths for a single collection with search and infinite scroll.
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
    final isPro = ref.watch(isProProvider);
    final state = ref.watch(hadithListProvider(widget.collection.name));

    final displayList =
        state.isInSearchMode ? state.searchResults : state.hadiths;

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

          // ── Free tier notice ─────────────────────────────────────────────
          if (!isPro && !state.isInSearchMode)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Showing first ${state.hadiths.length} hadiths — upgrade for full access',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
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

          // ── Search results (in search mode) ──────────────────────────────
          else if (state.isInSearchMode && state.isSearching)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
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

            // Pro locked card shown after free-tier hadiths
            if (!isPro && !state.isInSearchMode && displayList.isNotEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(child: HadithProLockedCard()),
              ),

            // Load more indicator (Pro)
            if (state.isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),

            // End-of-list (Pro)
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
