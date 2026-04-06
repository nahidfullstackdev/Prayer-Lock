import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/presentation/providers/quran_providers.dart';
import 'package:prayer_lock/features/quran/presentation/screens/surah_detail_screen.dart';

/// Screen displaying user's bookmarks
class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bookmarkState = ref.watch(bookmarksProvider);

    final gradientColors = isDark
        ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
        : [const Color(0xFF15803D), const Color(0xFF166534)];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: gradientColors.last,
        foregroundColor: Colors.white,
        title: const Text(
          'Bookmarks',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(bookmarksProvider.notifier).refresh(),
        child: _buildBody(context, ref, cs, bookmarkState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ColorScheme cs,
    dynamic bookmarkState,
  ) {
    if (bookmarkState.isLoading && bookmarkState.bookmarks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookmarkState.errorMessage != null &&
        bookmarkState.bookmarks.isEmpty) {
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
                bookmarkState.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(bookmarksProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (bookmarkState.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 40,
                color: cs.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No bookmarks yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any Ayah\nto save it here',
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: bookmarkState.bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = bookmarkState.bookmarks[index];
        return _BookmarkCard(
          colorScheme: cs,
          surahName: bookmark.surahName,
          ayahNumber: bookmark.ayahNumber,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SurahDetailScreen(
                surahId: bookmark.surahId,
                surahName: bookmark.surahName,
                initialAyahId: bookmark.ayahId,
              ),
            ),
          ),
          onDelete: () async {
            final success = await ref
                .read(bookmarksProvider.notifier)
                .removeBookmark(bookmark.surahId, bookmark.ayahId);
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bookmark removed'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        );
      },
    );
  }
}

// ─── Bookmark card ──────────────────────────────────────────────────────────

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.colorScheme,
    required this.surahName,
    required this.ayahNumber,
    required this.onTap,
    required this.onDelete,
  });

  final ColorScheme colorScheme;
  final String surahName;
  final int ayahNumber;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bookmark_rounded,
                  color: colorScheme.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surahName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ayah $ayahNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colorScheme.error.withValues(alpha: 0.7),
                  size: 20,
                ),
                onPressed: onDelete,
                tooltip: 'Remove bookmark',
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
