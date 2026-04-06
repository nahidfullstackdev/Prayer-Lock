import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/presentation/providers/quran_providers.dart';
import 'package:prayer_lock/features/quran/presentation/screens/surah_detail_screen.dart';

/// Screen for searching Ayahs by English or Bengali translation text
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    ref.read(searchProvider.notifier).clear();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchProvider.notifier).search(query);
    });
  }

  void _onClear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    ref.read(searchProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchState = ref.watch(searchProvider);

    final gradientColors = isDark
        ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
        : [const Color(0xFF15803D), const Color(0xFF166534)];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: gradientColors.last,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white70,
          decoration: InputDecoration(
            hintText: 'Search in English or Bangla...',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 15,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                    onPressed: _onClear,
                  )
                : null,
          ),
          onChanged: _onQueryChanged,
        ),
      ),
      body: _buildBody(context, cs, searchState),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, dynamic searchState) {
    // Empty / too-short query
    if (searchState.query.isEmpty || searchState.query.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.search_rounded,
                size: 40,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Search the Quran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter at least 2 characters to search',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Loading
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error
    if (searchState.errorMessage != null) {
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
                searchState.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No results
    if (searchState.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Results list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            '${searchState.results.length} result${searchState.results.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: searchState.results.length,
            itemBuilder: (context, index) {
              final ayah = searchState.results[index] as Ayah;
              return _SearchResultCard(
                colorScheme: cs,
                ayah: ayah,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SurahDetailScreen(
                      surahId: ayah.surahId,
                      surahName: 'Surah ${ayah.surahId}',
                      initialAyahId: ayah.id,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Search result card ─────────────────────────────────────────────────────

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.colorScheme,
    required this.ayah,
    required this.onTap,
  });

  final ColorScheme colorScheme;
  final Ayah ayah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Surah ${ayah.surahId}  •  Ayah ${ayah.ayahNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: colorScheme.outlineVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (ayah.textEnglish.isNotEmpty)
                Text(
                  ayah.textEnglish,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              if (ayah.textBengali.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ayah.textBengali,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (ayah.textArabic.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  ayah.textArabic,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.9,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
