import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';
import 'package:prayer_lock/features/quran/presentation/providers/quran_providers.dart';
import 'package:prayer_lock/features/quran/presentation/screens/bookmarks_screen.dart';
import 'package:prayer_lock/features/quran/presentation/screens/search_screen.dart';
import 'package:prayer_lock/features/quran/presentation/screens/surah_detail_screen.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/last_read_banner.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/surah_card.dart';

/// Main Quran screen
class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Future<dynamic> _lastReadFuture;

  @override
  void initState() {
    super.initState();
    _lastReadFuture = ref.read(getLastReadUseCaseProvider)();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Surah> _filterSurahs(List<Surah> surahs) {
    if (_searchQuery.isEmpty) return surahs;
    final q = _searchQuery.toLowerCase();
    return surahs.where((s) {
      return s.nameTransliteration.toLowerCase().contains(q) ||
          s.nameEnglish.toLowerCase().contains(q) ||
          s.nameArabic.contains(_searchQuery) ||
          '${s.id}'.contains(_searchQuery);
    }).toList();
  }

  void _openSurah(Surah surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surahId: surah.id,
          surahName: surah.nameTransliteration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surahListState = ref.watch(surahListProvider);
    final filtered = _filterSurahs(surahListState.surahs);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.read(surahListProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(cs)),

            // ── Search + Stats + Last Read ──────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _buildSearchBar(cs),
                    const SizedBox(height: 14),
                    _buildStatsRow(cs, surahListState.surahs.length),
                    _buildLastReadBanner(),
                  ],
                ),
              ),
            ),

            // ── Surah list ──────────────────────────────────────────────
            if (surahListState.isLoading && surahListState.surahs.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (surahListState.errorMessage != null &&
                surahListState.surahs.isEmpty)
              SliverFillRemaining(
                child: _buildErrorState(cs, surahListState.errorMessage!),
              )
            else if (filtered.isEmpty && _searchQuery.isNotEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No Surah found',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              _buildSurahSliver(cs, filtered),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: cs.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Al-Quran',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The Noble Quran  •  القرآن الكريم',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              icon: Icon(Icons.search_rounded, color: cs.primary),
              iconSize: 26,
              tooltip: 'Search Quran',
            ),
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookmarksScreen()),
              ),
              icon: Icon(Icons.bookmark_outline_rounded, color: cs.secondary),
              iconSize: 26,
              tooltip: 'Bookmarks',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────────────────────────

  Widget _buildSearchBar(ColorScheme cs) {
    return TextField(
      controller: _searchController,
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
      style: TextStyle(fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: 'Search Surah...',
        prefixIcon: Icon(
          Icons.search_rounded,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          size: 22,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
      ),
    );
  }

  // ─── Stats Row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow(ColorScheme cs, int surahCount) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _QuranStat(
                value: '$surahCount',
                label: 'Surahs',
                valueColor: cs.primary,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
            Expanded(
              child: _QuranStat(
                value: '6236',
                label: 'Verses',
                valueColor: cs.secondary,
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant),
            Expanded(
              child: _QuranStat(
                value: '30',
                label: 'Juz',
                valueColor: cs.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Last Read Banner ─────────────────────────────────────────────────────

  Widget _buildLastReadBanner() {
    return FutureBuilder<dynamic>(
      future: _lastReadFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return (snapshot.data as dynamic).fold(
          (_) => const SizedBox.shrink(),
          (lastRead) {
            if (lastRead == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LastReadBanner(
                lastRead: lastRead,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurahDetailScreen(
                      surahId: lastRead.surahId,
                      surahName: lastRead.surahName,
                      initialAyahId: lastRead.ayahId,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Surah Sliver List ────────────────────────────────────────────────────

  Widget _buildSurahSliver(ColorScheme cs, List<Surah> surahs) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      sliver: SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: surahs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant,
                indent: 68,
              ),
              itemBuilder: (context, index) => SurahCard(
                surah: surahs[index],
                onTap: () => _openSurah(surahs[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Error State ──────────────────────────────────────────────────────────

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
              onPressed: () => ref.read(surahListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat item widget ───────────────────────────────────────────────────────

class _QuranStat extends StatelessWidget {
  const _QuranStat({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
