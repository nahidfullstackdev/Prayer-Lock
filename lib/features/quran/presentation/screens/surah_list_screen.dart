import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/quran/presentation/providers/quran_providers.dart';
import 'package:prayer_lock/features/quran/presentation/screens/surah_detail_screen.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/last_read_banner.dart';
import 'package:prayer_lock/features/quran/presentation/widgets/surah_card.dart';

/// Screen displaying list of all 114 Surahs
class SurahListScreen extends ConsumerStatefulWidget {
  const SurahListScreen({super.key});

  @override
  ConsumerState<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends ConsumerState<SurahListScreen> {
  late Future<dynamic> _lastReadFuture;

  @override
  void initState() {
    super.initState();
    // Capture the future once so FutureBuilder never restarts on rebuild
    _lastReadFuture = ref.read(getLastReadUseCaseProvider)();
  }

  @override
  Widget build(BuildContext context) {
    final surahListState = ref.watch(surahListProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.read(surahListProvider.notifier).refresh(),
      child: Column(
        children: [
          // Last read banner
          FutureBuilder<dynamic>(
            future: _lastReadFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data == null) {
                return const SizedBox.shrink();
              }
              return (snapshot.data as dynamic).fold(
                (_) => const SizedBox.shrink(),
                (lastRead) {
                  if (lastRead == null) return const SizedBox.shrink();
                  return LastReadBanner(
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
                  );
                },
              );
            },
          ),
          // Surah list
          Expanded(child: _buildSurahList(context, surahListState)),
        ],
      ),
    );
  }

  Widget _buildSurahList(BuildContext context, surahListState) {
    if (surahListState.isLoading && surahListState.surahs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (surahListState.errorMessage != null && surahListState.surahs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              surahListState.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(surahListProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (surahListState.surahs.isEmpty) {
      return const Center(child: Text('No Surahs found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: surahListState.surahs.length,
      itemBuilder: (context, index) {
        final surah = surahListState.surahs[index];
        return SurahCard(
          surah: surah,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SurahDetailScreen(
                surahId: surah.id,
                surahName: surah.nameTransliteration,
              ),
            ),
          ),
        );
      },
    );
  }
}
