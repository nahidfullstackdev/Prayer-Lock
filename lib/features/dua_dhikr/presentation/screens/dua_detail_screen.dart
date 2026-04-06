import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/providers/dua_providers.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/widgets/dua_card.dart';

/// Shows all duas for a given [DuaCategory] with a search bar.
class DuaDetailScreen extends ConsumerStatefulWidget {
  const DuaDetailScreen({super.key, required this.category});

  final DuaCategory category;

  @override
  ConsumerState<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends ConsumerState<DuaDetailScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(duaListProvider(widget.category.id).notifier)
          .loadDuas();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(duaListProvider(widget.category.id));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: cs.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: cs.onSurface,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
                ),
                color: cs.onSurface,
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchController.clear();
                    ref
                        .read(duaListProvider(widget.category.id).notifier)
                        .clearSearch();
                  }
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    widget.category.arabic,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primary.withValues(alpha: 0.08),
                      cs.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Search bar ────────────────────────────────────────────────
          if (_showSearch)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search duas...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(
                                    duaListProvider(
                                      widget.category.id,
                                    ).notifier,
                                  )
                                  .clearSearch();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (q) {
                    setState(() {}); // rebuild suffix icon
                    ref
                        .read(duaListProvider(widget.category.id).notifier)
                        .search(q);
                  },
                ),
              ),
            ),

          // ── Loading / error ───────────────────────────────────────────
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.errorMessage != null && state.duas.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: cs.error,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref
                          .read(duaListProvider(widget.category.id).notifier)
                          .loadDuas(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.displayed.isEmpty && state.hasSearch)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'No duas found for "${state.searchQuery}"',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            // ── Dua list ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              sliver: SliverList.builder(
                itemCount: state.displayed.length,
                itemBuilder: (context, i) => DuaCard(
                  dua: state.displayed[i],
                  index: i,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
