import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/presentation/providers/hadith_providers.dart';
import 'package:prayer_lock/features/hadith/presentation/screens/hadith_list_screen.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';

/// Hadith home screen: shows all supported collections and navigates into each.
class HadithScreen extends ConsumerStatefulWidget {
  const HadithScreen({super.key});

  @override
  ConsumerState<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends ConsumerState<HadithScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hadithCollectionsProvider.notifier).loadCollections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPro = ref.watch(isProProvider);
    final state = ref.watch(hadithCollectionsProvider);

    // Fallback static collections used while loading / on error
    final collections = state.collections.isNotEmpty
        ? state.collections
        : _staticCollections();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.format_list_bulleted_rounded,
                            color: cs.secondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Hadith',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        if (state.isLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Prophetic Traditions  •  الأحاديث النبوية',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Error banner ──────────────────────────────────────────────
          if (state.errorMessage != null && state.collections.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ErrorBanner(
                  message: state.errorMessage!,
                  onRetry: () => ref
                      .read(hadithCollectionsProvider.notifier)
                      .loadCollections(),
                ),
              ),
            ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Collections',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // ── Collections list ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.builder(
              itemCount: collections.length,
              itemBuilder: (context, index) {
                final c = collections[index];
                // Free: first 2 collections unlocked; rest require Pro
                final bool locked = !isPro && index >= 2;
                return _CollectionCard(
                  collection: c,
                  locked: locked,
                  onTap: locked
                      ? () => _showProDialog(context, cs)
                      : () => _openCollection(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCollection(BuildContext context, HadithCollection collection) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HadithListScreen(collection: collection),
      ),
    );
  }

  void _showProDialog(BuildContext context, ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.lock_rounded, color: cs.secondary, size: 40),
            const SizedBox(height: 12),
            Text(
              'Pro Feature',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock all 10 hadith collections with Prayer Lock Pro. '
              'Browse thousands of authenticated hadiths from the major '
              'books of Sunnah in multiple languages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: trigger RevenueCat paywall
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.onSecondary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Upgrade to Pro',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Static fallback collections shown while the API loads or on error.
  /// Book keys match the fawazahmed0/hadith-api edition naming.
  List<HadithCollection> _staticCollections() => const [
        HadithCollection(
          name: 'bukhari',
          title: 'Sahih al-Bukhari',
          titleArabic: 'صحيح البخاري',
          totalHadith: 7563,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'rus', 'tam', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'muslim',
          title: 'Sahih Muslim',
          titleArabic: 'صحيح مسلم',
          totalHadith: 3033,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'rus', 'tam', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'tirmidhi',
          title: "Jami' at-Tirmidhi",
          titleArabic: 'جامع الترمذي',
          totalHadith: 3956,
          availableLanguages: ['ara', 'ben', 'eng', 'ind', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'abudawud',
          title: 'Sunan Abu Dawud',
          titleArabic: 'سنن أبي داود',
          totalHadith: 5274,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'rus', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'nasai',
          title: "Sunan an-Nasa'i",
          titleArabic: 'سنن النسائي',
          totalHadith: 5758,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'ibnmajah',
          title: 'Sunan Ibn Majah',
          titleArabic: 'سنن ابن ماجه',
          totalHadith: 4341,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'malik',
          title: 'Muwatta Malik',
          titleArabic: 'موطأ مالك',
          totalHadith: 1594,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'ind', 'tur', 'urd'],
        ),
        HadithCollection(
          name: 'nawawi',
          title: 'Forty Hadith of Nawawi',
          titleArabic: 'الأربعون النووية',
          totalHadith: 42,
          availableLanguages: ['ara', 'ben', 'eng', 'fra', 'tur'],
        ),
        HadithCollection(
          name: 'qudsi',
          title: 'Forty Hadith Qudsi',
          titleArabic: 'الأحاديث القدسية',
          totalHadith: 40,
          availableLanguages: ['ara', 'eng', 'fra'],
        ),
        HadithCollection(
          name: 'dehlawi',
          title: 'Forty Hadith of Dehlawi',
          titleArabic: 'أربعون حديثاً للدهلوي',
          totalHadith: 40,
          availableLanguages: ['ara', 'eng', 'fra'],
        ),
      ];
}

// ─── Collection card ─────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.locked,
    required this.onTap,
  });

  final HadithCollection collection;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: locked
                      ? cs.outlineVariant.withValues(alpha: 0.3)
                      : cs.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  locked
                      ? Icons.lock_rounded
                      : Icons.auto_stories_rounded,
                  color: locked ? cs.outlineVariant : cs.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),

              // Title + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: locked
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${collection.totalHadith} Hadiths',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Arabic + arrow
              Text(
                collection.titleArabic,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: cs.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: cs.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
