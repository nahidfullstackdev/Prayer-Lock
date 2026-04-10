// ─── Main Shell ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:prayer_lock/core/theme/theme_provider.dart';
import 'package:prayer_lock/features/app_blocker/presentation/screens/app_blocker_screen.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/screens/duadhikr_screen.dart';
import 'package:prayer_lock/features/hadith/presentation/screens/hadith_screen.dart';
import 'package:prayer_lock/features/home/presentation/screens/home_screen.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';
import 'package:prayer_lock/features/quran/presentation/screens/quran_home_screen.dart';
import 'package:prayer_lock/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const List<Widget> _screens = [
    HomeScreen(),
    QuranHomeScreen(),
    HadithScreen(),
    DuaDhikrScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedTabProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _screens[selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? cs.surface : Colors.white,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected:
              (i) => ref.read(selectedTabProvider.notifier).state = i,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Quran',
            ),
            NavigationDestination(
              icon: Icon(Icons.format_list_bulleted_rounded),
              selectedIcon: Icon(Icons.format_list_bulleted_rounded),
              label: 'Hadith',
            ),
            NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism_rounded),
              label: 'Dua',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── More Screen ────────────────────────────────────────────────────────────

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  static const List<(int, String)> _methods = [
    (0, 'Jafari / Shia Ithna-Ashari'),
    (1, 'University of Islamic Sciences, Karachi'),
    (2, 'Islamic Society of North America'),
    (3, 'Muslim World League'),
    (4, 'Umm Al-Qura University, Makkah'),
    (5, 'Egyptian General Authority of Survey'),
    (7, 'Institute of Geophysics, University of Tehran'),
    (8, 'Gulf Region'),
    (9, 'Kuwait'),
    (10, 'Qatar'),
    (11, 'Majlis Ugama Islam Singapura, Singapore'),
    (12, 'Union Organization Islamic de France'),
    (13, 'Diyanet İşleri Başkanlığı, Turkey'),
    (14, 'Spiritual Administration of Muslims of Russia'),
    (15, 'Moonsighting Committee Worldwide'),
    (16, 'Dubai'),
    (17, 'Jabatan Kemajuan Islam Malaysia (JAKIM)'),
    (18, 'Tunisia'),
    (19, 'Algeria'),
    (20, 'KEMENAG - Kementerian Agama Republik Indonesia'),
    (21, 'Morocco'),
    (22, 'Comunidade Islamica de Lisboa'),
    (23, 'Ministry of Awqaf, Jordan'),
  ];

  void _showMethodPicker(BuildContext context, WidgetRef ref, int current) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        'Calculation Method',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(
                          Icons.close_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _methods.length,
                    itemBuilder: (_, i) {
                      final (id, name) = _methods[i];
                      final selected = id == current;
                      return InkWell(
                        onTap: () {
                          ref
                              .read(prayerSettingsProvider.notifier)
                              .updateCalculationMethod(id);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? cs.primary.withValues(alpha: 0.15)
                                          : cs.surfaceContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '$id',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        selected
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        selected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                    color: selected ? cs.primary : cs.onSurface,
                                  ),
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsState = ref.watch(prayerSettingsProvider);
    final currentMethod = settingsState.settings.calculationMethod;

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
                            color: cs.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: cs.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'More',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Items ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    _MoreRow(
                      icon: Icons.calendar_month_rounded,
                      color: cs.primary,
                      title: 'Islamic Calendar',
                      onTap: () {},
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.explore_rounded,
                      color: cs.tertiary,
                      title: 'Qibla Compass',
                      onTap: () {},
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.mosque_rounded,
                      color: const Color(0xFF7C3AED),
                      title: 'Ramadan Tracker',
                      onTap: () {},
                    ),
                    if (Platform.isAndroid) ...[
                      Divider(height: 1, indent: 68, color: cs.outlineVariant),
                      _MoreRow(
                        icon: Icons.lock_outline_rounded,
                        color: cs.primary,
                        title: 'App Blocker',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const AppBlockerScreen(),
                              ),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Settings Section ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    // ── Theme Toggle ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: cs.secondary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: isDark,
                            onChanged:
                                (_) =>
                                    ref.read(themeProvider.notifier).toggle(),
                            activeColor: cs.primary,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    InkWell(
                      onTap:
                          () => _showMethodPicker(context, ref, currentMethod),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.calculate_outlined,
                                color: cs.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Calculation Method',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentMethod · ${settingsState.settings.calculationMethodName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: cs.outlineVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.notifications_outlined,
                      color: const Color(0xFFF59E0B),
                      title: 'Notifications',
                      onTap: () {},
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.info_outline_rounded,
                      color: cs.onSurfaceVariant,
                      title: 'About',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: cs.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
