import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayer_lock/features/app_blocker/presentation/screens/app_blocker_screen.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/location_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';
import 'package:prayer_lock/features/prayer_times/presentation/widgets/qibla_compass_sheet.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:prayer_lock/features/subscription/presentation/widgets/pro_paywall_sheet.dart';
import 'package:prayer_lock/main.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Guards against requesting the notification permission more than once per
  // session. A SharedPreferences flag (`_kNotifPermKey`) persists this across
  // restarts so the system dialog is never shown twice.
  bool _notifPermTriggered = false;
  static const String _kNotifPermKey = 'notification_permission_requested';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Post-onboarding case: user is already Pro when the home screen first
    // mounts (they just completed the paywall). The post-frame delay ensures
    // the UI has settled before the system dialog appears.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isProProvider)) _maybeRequestNotifPermission();
    });
  }

  /// Requests POST_NOTIFICATIONS permission exactly once.
  ///
  /// No-ops if the permission was already requested in a previous session
  /// (persisted via SharedPreferences) or if it was already triggered this
  /// session (in-memory guard).
  Future<void> _maybeRequestNotifPermission() async {
    if (_notifPermTriggered) return;
    _notifPermTriggered = true;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kNotifPermKey) ?? false) return;
    await prefs.setBool(_kNotifPermKey, true);

    if (!mounted) return;
    await ref.read(notificationServiceProvider).requestPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prayerState = ref.watch(prayerTimesProvider);
    final locationState = ref.watch(locationProvider);

    // In-app upgrade case: free user subscribes while already past onboarding.
    ref.listen<bool>(isProProvider, (previous, current) {
      if (current && previous == false) _maybeRequestNotifPermission();
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(context, prayerState, locationState),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickAccess(context),
                  const SizedBox(height: 20),
                  // if (!ref.watch(isProProvider)) ...[
                  //   _buildProBanner(context),
                  //   const SizedBox(height: 20),
                  // ],
                  _buildPrayerTimesList(context, prayerState),
                  const SizedBox(height: 20),
                  _buildVerseOfTheDay(context),
                  const SizedBox(height: 20),
                  _buildHadithOfTheDay(context),
                  const SizedBox(height: 20),
                  // ── DEBUG: remove this block when done testing ──────────
                  // const AdhanTestWidget(),
                  // ────────────────────────────────────────────────────────
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    PrayerTimesState prayerState,
    LocationState locationState,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final gradientColors =
        isDark
            ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
            : [const Color(0xFF15803D), const Color(0xFF166534)];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderTopRow(cs, locationState),
              const SizedBox(height: 22),
              ScaleTransition(
                scale: _pulseAnimation,
                child: _buildNextPrayerCard(cs, isDark, prayerState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderTopRow(ColorScheme cs, LocationState locationState) {
    final location = locationState.location;
    final locationName =
        location?.cityName ??
        location?.countryName ??
        (locationState.isLoading ? 'Locating...' : 'Set Location');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assalamu Alaikum',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  ref.read(locationProvider.notifier).refresh();
                  ref.invalidate(prayerTimesProvider);
                },
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locationName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (locationState.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.refresh_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildHijriDateBadge(cs),
      ],
    );
  }

  Widget _buildHijriDateBadge(ColorScheme cs) {
    final now = DateTime.now();
    final day = now.day.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            day,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          Text(
            _month(now.month),
            style: TextStyle(
              color: cs.secondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${now.year}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard(
    ColorScheme cs,
    bool isDark,
    PrayerTimesState prayerState,
  ) {
    final nextPrayer = prayerState.nextPrayer;
    final remaining = prayerState.timeRemaining;

    final hours = remaining?.inHours ?? 0;
    final minutes = remaining?.inMinutes.remainder(60) ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT PRAYER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nextPrayer?.name.displayName ?? '--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                nextPrayer?.name.arabicName ?? '',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                nextPrayer != null ? _formatTime(nextPrayer.time) : '--:--',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  remaining != null
                      ? '${hours}h ${minutes}m remaining'
                      : prayerState.isLoading
                      ? 'Loading...'
                      : '--',
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Access ─────────────────────────────────────────────────────────

  Widget _buildQuickAccess(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final quickItems = [
      _QuickItem(Icons.menu_book_rounded, 'Quran', cs.primary, 1),
      _QuickItem(Icons.format_list_bulleted_rounded, 'Hadith', cs.secondary, 2),
      _QuickItem(Icons.volunteer_activism_rounded, 'Duas', cs.tertiary, 3),
      const _QuickItem(Icons.nightlight_round, 'Dhikr', Color(0xFF7C3AED), 3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Feature Action Cards ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                gradientColors:
                    isDark
                        ? [const Color(0xFF052E16), const Color(0xFF14532D)]
                        : [const Color(0xFF15803D), const Color(0xFF166534)],
                borderColor: cs.primary.withValues(alpha: 0.35),
                icon: Icons.shield_rounded,
                bgIcon: Icons.shield_outlined,
                title: 'App Blocker',
                subtitle: 'Block distracting\napps during prayer',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AppBlockerScreen(),
                      ),
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildFeatureCard(
                gradientColors:
                    isDark
                        ? [const Color(0xFF042F2E), const Color(0xFF134E4A)]
                        : [const Color(0xFF0F766E), const Color(0xFF0D9488)],
                borderColor: cs.tertiary.withValues(alpha: 0.35),
                icon: Icons.explore_rounded,
                bgIcon: Icons.explore_outlined,
                title: 'Find Qibla',
                subtitle: 'Face the direction\nof the holy Kaaba',
                onTap: () => showQiblaSheet(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ── Quick Nav ─────────────────────────────────────────────────────
        Row(
          children:
              quickItems
                  .map(
                    (item) => Expanded(
                      child: GestureDetector(
                        onTap:
                            () =>
                                ref.read(selectedTabProvider.notifier).state =
                                    item.tabIndex,
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: item.color.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required List<Color> gradientColors,
    required Color borderColor,
    required IconData icon,
    required IconData bgIcon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(
                bgIcon,
                size: 84,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Prayer Times List ────────────────────────────────────────────────────

  Widget _buildPrayerTimesList(
    BuildContext context,
    PrayerTimesState prayerState,
  ) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dateStr = '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day}';

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Text(
                    'Prayer Times',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),
            if (prayerState.isLoading && prayerState.prayerTimes == null)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  ),
                ),
              )
            else if (prayerState.prayerTimes != null)
              ...prayerState.prayerTimes!.allPrayers.map(
                (prayer) => _buildPrayerRow(
                  context,
                  prayer,
                  isNext: prayerState.nextPrayer?.name == prayer.name,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  prayerState.errorMessage ??
                      'Enable location to see prayer times',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerRow(
    BuildContext context,
    Prayer prayer, {
    required bool isNext,
  }) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isPassed = prayer.time.isBefore(now) && !isNext;

    return Container(
      color: isNext ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  isNext
                      ? cs.primary.withValues(alpha: 0.15)
                      : cs.outlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _prayerIcon(prayer.name),
              size: 18,
              color:
                  isNext
                      ? cs.primary
                      : isPassed
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                prayer.name.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  color:
                      isNext
                          ? cs.primary
                          : isPassed
                          ? cs.onSurface.withValues(alpha: 0.5)
                          : cs.onSurface,
                ),
              ),
              Text(
                prayer.name.arabicName,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const Spacer(),
          if (isNext)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          Text(
            _formatTime(prayer.time),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isNext
                      ? cs.primary
                      : isPassed
                      ? cs.onSurface.withValues(alpha: 0.5)
                      : cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Verse of the Day ─────────────────────────────────────────────────────

  Widget _buildVerseOfTheDay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: cs.secondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Icon(Icons.auto_stories_rounded, size: 18, color: cs.secondary),
                const SizedBox(width: 8),
                Text(
                  'Verse of the Day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: cs.outlineVariant,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Text(
                  '\u0625\u0650\u0646\u064E\u0651 \u0645\u064E\u0639\u064E \u0627\u0644\u0652\u0639\u064F\u0633\u0652\u0631\u0650 \u064A\u064F\u0633\u0652\u0631\u064B\u0627',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 28,
                    color: cs.primary,
                    height: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Indeed, with hardship comes ease.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Surah Ash-Sharh 94:6',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hadith of the Day ────────────────────────────────────────────────────

  Widget _buildHadithOfTheDay(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Icon(Icons.format_quote_rounded, size: 18, color: cs.secondary),
                const SizedBox(width: 8),
                Text(
                  'Hadith of the Day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: cs.outlineVariant,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.secondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '"The best among you are those who have the best manners and character."',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.85),
                          fontStyle: FontStyle.italic,
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '— Sahih al-Bukhari',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pro Banner ───────────────────────────────────────────────────────────

  Widget _buildProBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap:
          () => showProPaywall(
            context,
            ref.read(subscriptionRepositoryProvider),
            placement: 'home_upgrade_cta',
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isDark
                    ? [const Color(0xFF2D1F00), const Color(0xFF1A1400)]
                    : [const Color(0xFFFDF6E3), const Color(0xFFFAEBB8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.secondary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: cs.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock Muslim Companion Pro',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ad-free · Audio recitation · Unlimited bookmarks',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: cs.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'See Plans',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour =
        hour == 0
            ? 12
            : hour > 12
            ? hour - 12
            : hour;
    return '$displayHour:$minute $period';
  }

  IconData _prayerIcon(PrayerName name) {
    switch (name) {
      case PrayerName.fajr:
        return Icons.nightlight_round;
      case PrayerName.dhuhr:
        return Icons.wb_sunny_rounded;
      case PrayerName.asr:
        return Icons.wb_cloudy_rounded;
      case PrayerName.maghrib:
        return Icons.wb_twilight_rounded;
      case PrayerName.isha:
        return Icons.nights_stay_rounded;
    }
  }

  String _weekday(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

// ─── Data Models ────────────────────────────────────────────────────────────

class _QuickItem {
  const _QuickItem(this.icon, this.label, this.color, this.tabIndex);
  final IconData icon;
  final String label;
  final Color color;
  final int tabIndex;
}
