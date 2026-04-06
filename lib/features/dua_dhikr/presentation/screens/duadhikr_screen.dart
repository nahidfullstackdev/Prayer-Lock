// ─── Dua & Dhikr Screen ────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/providers/dua_providers.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/screens/dua_detail_screen.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';

class DuaDhikrScreen extends ConsumerStatefulWidget {
  const DuaDhikrScreen({super.key});

  @override
  ConsumerState<DuaDhikrScreen> createState() => _DuaDhikrScreenState();
}

class _DuaDhikrScreenState extends ConsumerState<DuaDhikrScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(duaCategoriesProvider.notifier).loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPro = ref.watch(isProProvider);
    final catState = ref.watch(duaCategoriesProvider);
    final tasbih = ref.watch(tasbihProvider);

    final progress =
        tasbih.target > 0 ? (tasbih.count / tasbih.target).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.tertiary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.volunteer_activism_rounded,
                        color: cs.tertiary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dua & Dhikr',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Remembrance of Allah  •  ذكر الله',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (catState.isLoading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.tertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Error banner ──────────────────────────────────────────────
          if (catState.errorMessage != null && catState.categories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ErrorBanner(
                  message: catState.errorMessage!,
                  onRetry: () =>
                      ref.read(duaCategoriesProvider.notifier).loadCategories(),
                ),
              ),
            ),

          // ── Tasbih counter ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _TasbihCounter(tasbih: tasbih, progress: progress, cs: cs),
            ),
          ),

          // ── Section title ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (!isPro)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Pro unlocks 5 more',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Categories list ───────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList.builder(
              itemCount: catState.categories.isEmpty
                  ? _staticCategories.length
                  : catState.categories.length,
              itemBuilder: (context, index) {
                final cat = catState.categories.isEmpty
                    ? _staticCategories[index]
                    : catState.categories[index];
                final locked = !isPro && cat.isPro;
                return _CategoryCard(
                  category: cat,
                  locked: locked,
                  onTap: locked
                      ? () => _showProDialog(context, cs)
                      : () => _openCategory(context, cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, DuaCategory cat) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DuaDetailScreen(category: cat),
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
              'Unlock 5 additional dua categories — Travel, Health & Illness, '
              'Seeking Forgiveness, Anxiety & Worry, and Entering/Leaving Places '
              '— with Prayer Lock Pro.',
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
}

// ─── Tasbih counter widget ────────────────────────────────────────────────────

class _TasbihCounter extends ConsumerWidget {
  const _TasbihCounter({
    required this.tasbih,
    required this.progress,
    required this.cs,
  });

  final TasbihState tasbih;
  final double progress;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      child: Column(
        children: [
          Text(
            'Tasbih Counter',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          // ── Progress ring ───────────────────────────────────────────
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      tasbih.count >= tasbih.target
                          ? cs.tertiary
                          : cs.primary,
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${tasbih.count}',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: tasbih.count >= tasbih.target
                            ? cs.tertiary
                            : cs.primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'of ${tasbih.target}',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (tasbih.count >= tasbih.target) ...[
            const SizedBox(height: 12),
            Text(
              'سُبْحَانَ اللَّه  •  Subhanallah!',
              style: TextStyle(
                fontSize: 13,
                color: cs.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Target chips ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final t in [33, 99, 100])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$t'),
                    selected: tasbih.target == t,
                    onSelected: (_) =>
                        ref.read(tasbihProvider.notifier).setTarget(t),
                    selectedColor: cs.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      color: tasbih.target == t
                          ? cs.primary
                          : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: tasbih.target == t
                          ? cs.primary
                          : cs.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Action buttons ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TasbihButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                color: cs.error,
                onTap: () => ref.read(tasbihProvider.notifier).reset(),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => ref.read(tasbihProvider.notifier).increment(),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tasbih.count >= tasbih.target
                        ? cs.tertiary
                        : cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.locked,
    required this.onTap,
  });

  final DuaCategory category;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _iconFor(category.iconName);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
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
                  color: locked
                      ? cs.outlineVariant.withValues(alpha: 0.25)
                      : cs.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  locked ? Icons.lock_rounded : icon,
                  color: locked ? cs.outlineVariant : cs.tertiary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: locked
                            ? cs.onSurface.withValues(alpha: 0.45)
                            : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.arabic,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 12,
                        color: locked
                            ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!locked)
                Text(
                  '${category.duaCount} duas',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: cs.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(String name) => switch (name) {
        'wb_sunny_rounded' => Icons.wb_sunny_rounded,
        'nights_stay_rounded' => Icons.nights_stay_rounded,
        'mosque_rounded' => Icons.mosque_rounded,
        'bedtime_rounded' => Icons.bedtime_rounded,
        'calendar_today_rounded' => Icons.calendar_today_rounded,
        'restaurant_rounded' => Icons.restaurant_rounded,
        'flight_rounded' => Icons.flight_rounded,
        'medical_services_rounded' => Icons.medical_services_rounded,
        'favorite_rounded' => Icons.favorite_rounded,
        'psychology_rounded' => Icons.psychology_rounded,
        'door_front_door_rounded' => Icons.door_front_door_rounded,
        _ => Icons.auto_awesome_rounded,
      };
}

// ─── Tasbih helper button ─────────────────────────────────────────────────────

class _TasbihButton extends StatelessWidget {
  const _TasbihButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
          Icon(
            Icons.warning_amber_rounded,
            color: cs.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
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

// ─── Static fallback categories (while JSON loads) ────────────────────────────

const _staticCategories = [
  _StaticCategory(
    id: 'morning_adhkar',
    name: 'Morning Adhkar',
    arabic: 'أذكار الصباح',
    iconName: 'wb_sunny_rounded',
    isPro: false,
    duaCount: 5,
  ),
  _StaticCategory(
    id: 'evening_adhkar',
    name: 'Evening Adhkar',
    arabic: 'أذكار المساء',
    iconName: 'nights_stay_rounded',
    isPro: false,
    duaCount: 5,
  ),
  _StaticCategory(
    id: 'after_salah',
    name: 'After Salah',
    arabic: 'أذكار بعد الصلاة',
    iconName: 'mosque_rounded',
    isPro: false,
    duaCount: 4,
  ),
  _StaticCategory(
    id: 'before_sleep',
    name: 'Before Sleep',
    arabic: 'أذكار النوم',
    iconName: 'bedtime_rounded',
    isPro: false,
    duaCount: 4,
  ),
  _StaticCategory(
    id: 'daily_duas',
    name: 'Daily Duas',
    arabic: 'أدعية يومية',
    iconName: 'calendar_today_rounded',
    isPro: false,
    duaCount: 4,
  ),
  _StaticCategory(
    id: 'food_drink',
    name: 'Food & Drink',
    arabic: 'أدعية الطعام والشراب',
    iconName: 'restaurant_rounded',
    isPro: false,
    duaCount: 3,
  ),
  _StaticCategory(
    id: 'travel',
    name: 'Travel Duas',
    arabic: 'أدعية السفر',
    iconName: 'flight_rounded',
    isPro: true,
    duaCount: 3,
  ),
  _StaticCategory(
    id: 'health_illness',
    name: 'Health & Illness',
    arabic: 'أدعية المرض والشفاء',
    iconName: 'medical_services_rounded',
    isPro: true,
    duaCount: 3,
  ),
  _StaticCategory(
    id: 'seeking_forgiveness',
    name: 'Seeking Forgiveness',
    arabic: 'أذكار الاستغفار',
    iconName: 'favorite_rounded',
    isPro: true,
    duaCount: 3,
  ),
  _StaticCategory(
    id: 'anxiety_worry',
    name: 'Anxiety & Worry',
    arabic: 'أدعية الهم والحزن',
    iconName: 'psychology_rounded',
    isPro: true,
    duaCount: 3,
  ),
  _StaticCategory(
    id: 'entering_leaving',
    name: 'Entering & Leaving',
    arabic: 'أدعية الدخول والخروج',
    iconName: 'door_front_door_rounded',
    isPro: true,
    duaCount: 3,
  ),
];

class _StaticCategory extends DuaCategory {
  const _StaticCategory({
    required super.id,
    required super.name,
    required super.arabic,
    required super.iconName,
    required super.isPro,
    required super.duaCount,
  }) : super(description: '', orderIndex: 0);
}
