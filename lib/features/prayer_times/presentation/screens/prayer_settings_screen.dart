import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/location_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_settings_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  static const _calculationMethods = [
    _Method(2, 'Islamic Society of North America (ISNA)', 'North America'),
    _Method(3, 'Muslim World League (MWL)', 'Europe, Far East, parts of USA'),
    _Method(4, 'Umm Al-Qura University, Makkah', 'Arabian Peninsula'),
    _Method(5, 'Egyptian General Authority of Survey', 'Africa, Syria, Lebanon, Malaysia'),
    _Method(1, 'University of Islamic Sciences, Karachi', 'Pakistan, Bangladesh, India, Afghanistan'),
    _Method(7, 'Gulf Region', 'Gulf States'),
    _Method(8, 'Kuwait', 'Kuwait'),
    _Method(9, 'Qatar', 'Qatar'),
    _Method(10, 'Majlis Ugama Islam Singapura', 'Singapore, Malaysia, Indonesia'),
    _Method(11, 'Union Organization Islamic de France', 'France'),
    _Method(12, 'Diyanet İşleri Başkanlığı', 'Turkey'),
    _Method(13, 'Spiritual Administration of Muslims of Russia', 'Russia'),
    _Method(14, 'Moonsighting Committee Worldwide', 'Global — moon sighting based'),
    _Method(15, 'Dubai', 'UAE (experimental)'),
    _Method(6, 'Institute of Geophysics, University of Tehran', 'Iran'),
    _Method(0, 'Shia Ithna-Ashari', 'Shia communities'),
  ];

  static const _minutesBeforeOptions = [0, 5, 10, 15];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prayerSettingsProvider);
    final locationState = ref.watch(locationProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Prayer Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
                        : [const Color(0xFF15803D), const Color(0xFF166534)],
                  ),
                ),
              ),
            ),
          ),

          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Location ─────────────────────────────────────────
                    _buildSectionTitle('Your Location', cs),
                    const SizedBox(height: 8),
                    _buildLocationCard(context, ref, locationState, cs),

                    const SizedBox(height: 24),

                    // ── Calculation Method ───────────────────────────────
                    _buildSectionTitle('Calculation Method', cs),
                    const SizedBox(height: 8),
                    _buildCalculationMethodCard(context, ref, state, cs),

                    const SizedBox(height: 24),

                    // ── Madhab ───────────────────────────────────────────
                    _buildSectionTitle('Asr Calculation (Madhab)', cs),
                    const SizedBox(height: 8),
                    _buildMadhabCard(context, ref, state, cs),

                    const SizedBox(height: 24),

                    // ── Notifications ────────────────────────────────────
                    _buildSectionTitle('Prayer Notifications', cs),
                    const SizedBox(height: 8),
                    _buildNotificationsCard(context, ref, state, cs),

                    const SizedBox(height: 24),

                    // ── Notification Timing ──────────────────────────────
                    _buildSectionTitle('Notify Before Prayer', cs),
                    const SizedBox(height: 8),
                    _buildMinutesBeforeCard(context, ref, state, cs),

                    const SizedBox(height: 24),

                    // ── Refresh Note ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: cs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Changing calculation method or madhab will refresh prayer times on the next load.',
                              style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Section Title ────────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ─── Location Card ────────────────────────────────────────────────────────

  Widget _buildLocationCard(
    BuildContext context,
    WidgetRef ref,
    LocationState locationState,
    ColorScheme cs,
  ) {
    final location = locationState.location;
    final cityName = location?.cityName;
    final countryName = location?.countryName;
    final hasName = cityName != null || countryName != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: cs.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (locationState.isLoading)
                      Text(
                        'Detecting location...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    else if (locationState.isPermissionDenied)
                      Text(
                        'Location Permission Denied',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.error,
                        ),
                      )
                    else if (hasName)
                      Text(
                        [
                          if (cityName != null) cityName,
                          if (countryName != null) countryName,
                        ].join(', '),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Text(
                        'Location not set',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    if (location != null && !locationState.isLoading)
                      Text(
                        '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    if (locationState.errorMessage != null &&
                        !locationState.isPermissionDenied)
                      Text(
                        locationState.errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (locationState.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.primary,
                  ),
                )
              else
                IconButton(
                  onPressed: () {
                    ref.read(locationProvider.notifier).refresh();
                    // Also refresh prayer times with new location
                    ref.invalidate(prayerTimesProvider);
                  },
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: cs.primary,
                  ),
                  tooltip: 'Refresh location',
                ),
            ],
          ),
          if (locationState.isPermissionDenied) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.read(locationProvider.notifier).refresh();
                },
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('Grant Location Access'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Calculation Method ───────────────────────────────────────────────────

  Widget _buildCalculationMethodCard(
    BuildContext context,
    WidgetRef ref,
    PrayerSettingsState state,
    ColorScheme cs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _calculationMethods.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: cs.outlineVariant),
            InkWell(
              onTap: () {
                ref
                    .read(prayerSettingsProvider.notifier)
                    .updateCalculationMethod(_calculationMethods[i].id);
                // Invalidate prayer times to refetch with new method
                ref.invalidate(prayerTimesProvider);
              },
              borderRadius: i == 0
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : i == _calculationMethods.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        )
                      : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _calculationMethods[i].name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: state.settings.calculationMethod ==
                                      _calculationMethods[i].id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: state.settings.calculationMethod ==
                                      _calculationMethods[i].id
                                  ? cs.primary
                                  : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _calculationMethods[i].region,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (state.settings.calculationMethod ==
                        _calculationMethods[i].id)
                      Icon(
                        Icons.check_circle_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Madhab ───────────────────────────────────────────────────────────────

  Widget _buildMadhabCard(
    BuildContext context,
    WidgetRef ref,
    PrayerSettingsState state,
    ColorScheme cs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          _buildMadhabRow(
            ref: ref,
            state: state,
            cs: cs,
            value: 0,
            title: 'Shafi / Maliki / Hanbali',
            subtitle: 'Standard calculation',
            isFirst: true,
          ),
          Divider(height: 1, indent: 16, color: cs.outlineVariant),
          _buildMadhabRow(
            ref: ref,
            state: state,
            cs: cs,
            value: 1,
            title: 'Hanafi',
            subtitle: 'Later Asr time',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMadhabRow({
    required WidgetRef ref,
    required PrayerSettingsState state,
    required ColorScheme cs,
    required int value,
    required String title,
    required String subtitle,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final isSelected = state.settings.madhab == value;

    return InkWell(
      onTap: () {
        ref.read(prayerSettingsProvider.notifier).updateMadhab(value);
        ref.invalidate(prayerTimesProvider);
      },
      borderRadius: isFirst
          ? const BorderRadius.vertical(top: Radius.circular(16))
          : isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(16))
              : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  Widget _buildNotificationsCard(
    BuildContext context,
    WidgetRef ref,
    PrayerSettingsState state,
    ColorScheme cs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < PrayerName.values.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: cs.outlineVariant),
            _buildNotificationRow(
              ref: ref,
              state: state,
              cs: cs,
              prayer: PrayerName.values[i],
              isFirst: i == 0,
              isLast: i == PrayerName.values.length - 1,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationRow({
    required WidgetRef ref,
    required PrayerSettingsState state,
    required ColorScheme cs,
    required PrayerName prayer,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final enabled = state.settings.notificationsEnabled[prayer] ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: enabled
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.outlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 18,
              color: enabled ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  prayer.arabicName,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: (_) {
              ref.read(prayerSettingsProvider.notifier).toggleNotification(prayer);
            },
            activeColor: cs.primary,
          ),
        ],
      ),
    );
  }

  // ─── Minutes Before ───────────────────────────────────────────────────────

  Widget _buildMinutesBeforeCard(
    BuildContext context,
    WidgetRef ref,
    PrayerSettingsState state,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Alert before adhan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (final minutes in _minutesBeforeOptions)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(minutes == 0 ? 'At time' : '${minutes}m'),
                selected: state.settings.notificationMinutesBefore == minutes,
                onSelected: (_) {
                  ref
                      .read(prayerSettingsProvider.notifier)
                      .updateMinutesBefore(minutes);
                },
                selectedColor: cs.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: state.settings.notificationMinutesBefore == minutes
                      ? cs.primary
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: state.settings.notificationMinutesBefore == minutes
                      ? cs.primary
                      : cs.outlineVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _Method {
  final int id;
  final String name;
  final String region;
  const _Method(this.id, this.name, this.region);
}
