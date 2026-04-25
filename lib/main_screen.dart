// ─── Main Shell ─────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_lock/core/theme/theme_provider.dart';
import 'package:prayer_lock/features/app_blocker/presentation/providers/app_blocker_providers.dart';
import 'package:prayer_lock/features/app_blocker/presentation/screens/app_blocker_screen.dart';
import 'package:prayer_lock/features/calendar/presentation/screens/islamic_calendar_screen.dart';
import 'package:prayer_lock/features/calendar/presentation/screens/ramadan_tracker_screen.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/screens/duadhikr_screen.dart';
import 'package:prayer_lock/features/hadith/presentation/screens/hadith_screen.dart';
import 'package:prayer_lock/features/home/presentation/screens/home_screen.dart';
import 'package:prayer_lock/features/home_widget/data/services/home_widget_service.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';
import 'package:prayer_lock/features/prayer_times/presentation/widgets/notification_settings_sheet.dart';
import 'package:prayer_lock/features/prayer_times/presentation/widgets/qibla_compass_sheet.dart';
import 'package:prayer_lock/features/quran/presentation/screens/quran_home_screen.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:prayer_lock/features/subscription/presentation/widgets/pro_paywall_sheet.dart';
import 'package:prayer_lock/main.dart';

// Keep in sync with version in pubspec.yaml
const String _kAppVersion = '1.0.1';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  static const List<Widget> _screens = [
    HomeScreen(),
    QuranHomeScreen(),
    HadithScreen(),
    DuaDhikrScreen(),
    MoreScreen(),
  ];

  /// True while the user is inside a special-permission Settings page that we
  /// opened. When they return (AppLifecycleState.resumed) we re-check and
  /// re-show the sheet only in that case, avoiding annoying repeated prompts.
  bool _openedSpecialSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _bootstrapPermissions(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only re-evaluate when we know the user came back from a Settings page
    // that we explicitly sent them to.
    if (state == AppLifecycleState.resumed && _openedSpecialSettings) {
      _openedSpecialSettings = false;
      if (Platform.isAndroid) _checkAndMaybeShowSpecialPermsSheet();
    }
  }

  // ── Permission bootstrap ─────────────────────────────────────────────────────

  Future<void> _bootstrapPermissions() async {
    if (!mounted) return;

    // Standard permissions: system handles duplicates; no-op if already granted.
    await [Permission.notification, Permission.locationWhenInUse].request();

    // Special Android permissions require the user to visit a Settings page.
    if (Platform.isAndroid && mounted) {
      await _checkAndMaybeShowSpecialPermsSheet();
    }
  }

  Future<void> _checkAndMaybeShowSpecialPermsSheet() async {
    if (!mounted) return;
    final repo = ref.read(appBlockerRepositoryProvider);
    final hasUsage = (await repo.hasUsageStatsPermission()).fold(
      (_) => false,
      (v) => v,
    );
    final hasOverlay = (await repo.hasOverlayPermission()).fold(
      (_) => false,
      (v) => v,
    );
    if (hasUsage && hasOverlay) return;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetCtx) => _SpecialPermissionsSheet(
            hasUsageStats: hasUsage,
            hasOverlay: hasOverlay,
            onGrantUsage: () {
              _openedSpecialSettings = true;
              Navigator.pop(sheetCtx);
              repo.openUsageStatsSettings();
            },
            onGrantOverlay: () {
              _openedSpecialSettings = true;
              Navigator.pop(sheetCtx);
              repo.openOverlaySettings();
            },
          ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AboutSheet(),
    );
  }

  /// Tries to pin the Prayer Lock widget to the launcher. Falls back to
  /// an instructional sheet when the launcher doesn't support programmatic
  /// pinning (common on older Android launchers and always on iOS).
  Future<void> _addHomeWidget(BuildContext context) async {
    if (!Platform.isAndroid) {
      _showAddWidgetSheet(context, manual: true);
      return;
    }

    final supported = await HomeWidgetService.isPinWidgetSupported();
    if (!context.mounted) return;

    if (!supported) {
      _showAddWidgetSheet(context, manual: true);
      return;
    }

    // The plugin does not report whether the launcher prompt was accepted,
    // so we just fire-and-forget. If the launcher dialog is dismissed, the
    // user can still long-press the home screen and add it manually.
    await HomeWidgetService.requestPinWidget();
  }

  void _showAddWidgetSheet(BuildContext context, {required bool manual}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWidgetSheet(manual: manual),
    );
  }

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
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const IslamicCalendarScreen(),
                            ),
                          ),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.explore_rounded,
                      color: cs.tertiary,
                      title: 'Qibla Compass',
                      onTap: () => showQiblaSheet(context),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.mosque_rounded,
                      color: const Color(0xFF7C3AED),
                      title: 'Ramadan Tracker',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const RamadanTrackerScreen(),
                            ),
                          ),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.widgets_rounded,
                      color: const Color(0xFF0EA5E9),
                      title: 'Home Screen Widget',
                      onTap: () => _addHomeWidget(context),
                    ),
                    if (Platform.isAndroid) ...[
                      Divider(height: 1, indent: 68, color: cs.outlineVariant),
                      _MoreRow(
                        icon: Icons.lock_outline_rounded,
                        color: cs.primary,
                        title: 'App Blocker',
                        trailing: ref.watch(isProProvider)
                            ? null
                            : const _ProBadge(),
                        onTap: () {
                          if (ref.read(isProProvider)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const AppBlockerScreen(),
                              ),
                            );
                          } else {
                            showProPaywall(
                              context,
                              ref.read(subscriptionRepositoryProvider),
                              placement: 'app_blocker_locked',
                              featureTitle: 'App Blocker',
                              featureDescription:
                                  'Block distracting apps during every Salah window.',
                            );
                          }
                        },
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                      onTap: () => showNotificationSettings(context),
                    ),
                    Divider(height: 1, indent: 68, color: cs.outlineVariant),
                    _MoreRow(
                      icon: Icons.info_outline_rounded,
                      color: cs.onSurfaceVariant,
                      title: 'About',
                      onTap: () => _showAboutSheet(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Version footer ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 36),
              child: Text(
                'Prayer Lock v$_kAppVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
    this.trailing,
  });
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

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
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
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

// ─── PRO badge ───────────────────────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: cs.secondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: isDark ? const Color(0xFF1A1A00) : Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── Special Permissions Sheet ────────────────────────────────────────────────
//
// Shown once on first launch (Android only) when Usage Access and/or Display
// Over Other Apps have not been granted. Each row sends the user to the
// relevant system settings page. The parent re-checks on return and only
// re-shows if permissions are still missing.

class _SpecialPermissionsSheet extends StatelessWidget {
  const _SpecialPermissionsSheet({
    required this.hasUsageStats,
    required this.hasOverlay,
    required this.onGrantUsage,
    required this.onGrantOverlay,
  });

  final bool hasUsageStats;
  final bool hasOverlay;
  final VoidCallback onGrantUsage;
  final VoidCallback onGrantOverlay;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permissions Required',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Needed for the App Blocker to work correctly.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Permission rows
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? cs.surfaceContainer.withValues(alpha: 0.55)
                          : cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    if (!hasUsageStats) ...[
                      _PermRow(
                        icon: Icons.query_stats_rounded,
                        title: 'Usage Access',
                        subtitle:
                            'Detects which app is in the foreground so Prayer Lock can block it during Salah.',
                        cs: cs,
                        onGrant: onGrantUsage,
                      ),
                      if (!hasOverlay)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                    ],
                    if (!hasOverlay)
                      _PermRow(
                        icon: Icons.layers_rounded,
                        title: 'Display Over Other Apps',
                        subtitle:
                            'Shows the prayer reminder on top of blocked apps so you can confirm you prayed.',
                        cs: cs,
                        onGrant: onGrantOverlay,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Skip link
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Skip for now',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.onGrant,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFF59E0B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onGrant,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Grant',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add Home Widget Sheet ───────────────────────────────────────────────────
//
// Shown either when the launcher refuses programmatic pinning
// (requestPinAppWidget returned false / unsupported) or on iOS where
// WidgetKit must be pinned by the user from the widget gallery.

class _AddWidgetSheet extends StatelessWidget {
  const _AddWidgetSheet({required this.manual});

  final bool manual;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;
    final isIos = Platform.isIOS;

    final steps = isIos
        ? const [
            'Long-press any empty spot on your Home Screen.',
            'Tap the ＋ button in the top-left corner.',
            'Search for "Prayer Lock" and pick a size.',
            'Tap Add Widget, then Done.',
          ]
        : const [
            'Long-press any empty spot on your home screen.',
            'Tap "Widgets".',
            'Find "Prayer Lock" in the list.',
            'Drag "Next Prayer" onto your home screen.',
          ];

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.widgets_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add the Prayer Lock widget',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'See the next prayer and countdown at a glance.',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (manual)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < steps.length; i++) ...[
                        _WidgetStepRow(index: i + 1, text: steps[i]),
                        if (i < steps.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WidgetStepRow extends StatelessWidget {
  const _WidgetStepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── About Sheet ─────────────────────────────────────────────────────────────

class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cs.primary, cs.tertiary],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.mosque_rounded, color: cs.onPrimary, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              'Prayer Lock',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Build Discipline, Pray on Time',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Version $_kAppVersion',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Built for modern Muslims who struggle with focus in a digital world — combining essential daily tools with behavior-driven features to guide you toward maintaining Salah on time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? cs.surfaceContainer.withValues(alpha: 0.55)
                          : cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    const _AboutInfoRow(
                      icon: Icons.menu_book_rounded,
                      label: 'Quran text',
                      value: 'Al-Quran Cloud API',
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const _AboutInfoRow(
                      icon: Icons.access_time_rounded,
                      label: 'Prayer times',
                      value: 'Aladhan API',
                    ),
                    Divider(
                      height: 1,
                      indent: 56,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const _AboutInfoRow(
                      icon: Icons.code_rounded,
                      label: 'Developer',
                      value: 'MdNahid.com',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                '© ${DateTime.now().year} Prayer Lock · All rights reserved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  const _AboutInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: cs.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
