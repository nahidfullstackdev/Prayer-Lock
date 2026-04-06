import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';
import 'package:prayer_lock/features/prayer_times/presentation/screens/prayer_settings_screen.dart';

class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prayerTimesProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(prayerTimesProvider.notifier).refresh(),
        color: cs.primary,
        child: CustomScrollView(
          slivers: [
            // ── Header with next prayer countdown ──────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, state, isDark, cs),
            ),

            // ── Content ────────────────────────────────────────────────
            if (state.isLoading && state.prayerTimes == null)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null && state.prayerTimes == null)
              SliverFillRemaining(
                child: _buildErrorState(context, ref, state, cs),
              )
            else if (state.prayerTimes != null) ...[
              // ── Location & Date Info ─────────────────────────────────
              SliverToBoxAdapter(
                child: _buildInfoBar(context, state, cs),
              ),

              // ── Prayer Times List ───────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverToBoxAdapter(
                  child: _buildPrayerTimesCard(context, state, cs),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(
    BuildContext context,
    PrayerTimesState state,
    bool isDark,
    ColorScheme cs,
  ) {
    final gradientColors = isDark
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
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Row ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Prayer Times',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const PrayerSettingsScreen(),
                      ),
                    ),
                    icon: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Next Prayer Card ─────────────────────────────────────
              _buildNextPrayerCard(state, cs, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard(
    PrayerTimesState state,
    ColorScheme cs,
    bool isDark,
  ) {
    final nextPrayer = state.nextPrayer;
    final remaining = state.timeRemaining;

    final hours = remaining != null ? remaining.inHours : 0;
    final minutes = remaining != null ? remaining.inMinutes.remainder(60) : 0;
    final seconds = remaining != null ? remaining.inSeconds.remainder(60) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
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
                  const SizedBox(height: 6),
                  Text(
                    nextPrayer?.name.displayName ?? '--',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    nextPrayer?.name.arabicName ?? '',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
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
                  const SizedBox(height: 8),
                  if (remaining != null)
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
                        '${hours}h ${minutes}m ${seconds}s',
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
        ],
      ),
    );
  }

  // ─── Info Bar ─────────────────────────────────────────────────────────────

  Widget _buildInfoBar(
    BuildContext context,
    PrayerTimesState state,
    ColorScheme cs,
  ) {
    final prayerTimes = state.prayerTimes!;
    final location = prayerTimes.location;
    final locationName = location.cityName ?? location.countryName ?? 'Current Location';
    final date = prayerTimes.date;
    final dateStr =
        '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: cs.primary,
            size: 16,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              locationName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Prayer Times Card ────────────────────────────────────────────────────

  Widget _buildPrayerTimesCard(
    BuildContext context,
    PrayerTimesState state,
    ColorScheme cs,
  ) {
    final prayers = state.prayerTimes!.allPrayers;
    final nextPrayer = state.nextPrayer;

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
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  Text(
                    'Today\'s Prayers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    state.prayerTimes!.calculationMethod,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outlineVariant),

            // Prayer rows
            for (final prayer in prayers)
              _buildPrayerRow(
                context,
                prayer,
                isNext: nextPrayer?.name == prayer.name,
                cs: cs,
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
    required ColorScheme cs,
  }) {
    final icon = _prayerIcon(prayer.name);
    final now = DateTime.now();
    final isPassed = prayer.time.isBefore(now) && !isNext;

    return Container(
      color: isNext ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isNext
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.outlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isNext
                  ? cs.primary
                  : isPassed
                      ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                      : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.name.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                    color: isNext
                        ? cs.primary
                        : isPassed
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : cs.onSurface,
                  ),
                ),
                Text(
                  prayer.name.arabicName,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
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
          // Notification icon
          if (prayer.notificationEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                Icons.notifications_active_rounded,
                size: 14,
                color: isNext
                    ? cs.primary.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          Text(
            _formatTime(prayer.time),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isNext
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

  // ─── Error State ──────────────────────────────────────────────────────────

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    PrayerTimesState state,
    ColorScheme cs,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.isPermissionDenied
                  ? Icons.location_off_rounded
                  : Icons.cloud_off_rounded,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              state.isPermissionDenied
                  ? 'Location Permission Needed'
                  : 'Unable to Load Prayer Times',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'An unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                AppLogger.info('Retrying prayer times load...');
                ref.read(prayerTimesProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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
    final displayHour = hour == 0
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
