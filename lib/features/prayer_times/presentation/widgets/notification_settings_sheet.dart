import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/prayer_times/data/services/native_alarm_service.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

/// Opens the notification customisation sheet from any [BuildContext].
void showNotificationSettings(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationSettingsSheet(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationSettingsSheet extends ConsumerWidget {
  const _NotificationSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;
    final settings = ref.watch(prayerSettingsProvider).settings;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
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

              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
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
                        Icons.notifications_active_rounded,
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
                            'Notification Settings',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'Customize your prayer alerts',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Section: Prayer Alerts ───────────────────────────────────
              _SectionLabel(label: 'Prayer Alerts', cs: cs),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainer.withValues(alpha: 0.55)
                        : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < PrayerName.values.length; i++) ...[
                        _PrayerToggleRow(
                          prayer: PrayerName.values[i],
                          enabled:
                              settings.notificationsEnabled[PrayerName.values[i]] ??
                              true,
                          cs: cs,
                          onToggle: () => _togglePrayer(ref, PrayerName.values[i]),
                        ),
                        if (i < PrayerName.values.length - 1)
                          Divider(
                            height: 1,
                            indent: 68,
                            color: cs.outlineVariant,
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Section: Advance Reminder ────────────────────────────────
              _SectionLabel(label: 'Advance Reminder', cs: cs),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ReminderTimePicker(
                  selected: settings.notificationMinutesBefore,
                  cs: cs,
                  onSelect: (minutes) => _updateMinutesBefore(ref, minutes),
                ),
              ),

              const SizedBox(height: 20),

              // ── Section: Adhan Sound ─────────────────────────────────────
              _SectionLabel(label: 'Adhan Sound', cs: cs),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? cs.surfaceContainer.withValues(alpha: 0.55)
                        : cs.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      _AdhanTypeRow(
                        adhanType: AdhanType.standard,
                        selected: settings.adhanType == AdhanType.standard,
                        cs: cs,
                        onTap: () => _updateAdhanType(ref, AdhanType.standard),
                      ),
                      Divider(
                        height: 1,
                        indent: 68,
                        color: cs.outlineVariant,
                      ),
                      _AdhanTypeRow(
                        adhanType: AdhanType.silent,
                        selected: settings.adhanType == AdhanType.silent,
                        cs: cs,
                        onTap: () => _updateAdhanType(ref, AdhanType.silent),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Section: Reliability ─────────────────────────────────────
              _SectionLabel(label: 'Reliability', cs: cs),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _ReliabilitySection(),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePrayer(WidgetRef ref, PrayerName prayer) {
    ref.read(prayerSettingsProvider.notifier).toggleNotification(prayer);
    _reschedule(ref);
  }

  void _updateMinutesBefore(WidgetRef ref, int minutes) {
    ref.read(prayerSettingsProvider.notifier).updateMinutesBefore(minutes);
    _reschedule(ref);
  }

  void _updateAdhanType(WidgetRef ref, AdhanType type) {
    ref.read(prayerSettingsProvider.notifier).updateAdhanType(type);
    _reschedule(ref);
  }

  /// Reads the (already-updated) settings and reschedules alarms immediately.
  void _reschedule(WidgetRef ref) {
    final settings = ref.read(prayerSettingsProvider).settings;
    ref.read(prayerTimesProvider.notifier).scheduleNotifications(settings);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.cs});

  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prayer toggle row
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerToggleRow extends StatelessWidget {
  const _PrayerToggleRow({
    required this.prayer,
    required this.enabled,
    required this.cs,
    required this.onToggle,
  });

  final PrayerName prayer;
  final bool enabled;
  final ColorScheme cs;
  final VoidCallback onToggle;

  static (IconData, Color) _iconFor(PrayerName p) {
    switch (p) {
      case PrayerName.fajr:
        return (Icons.brightness_3_rounded, const Color(0xFF6366F1));
      case PrayerName.dhuhr:
        return (Icons.wb_sunny_rounded, const Color(0xFFF59E0B));
      case PrayerName.asr:
        return (Icons.filter_drama_rounded, const Color(0xFFF97316));
      case PrayerName.maghrib:
        return (Icons.wb_twilight_rounded, const Color(0xFFEF4444));
      case PrayerName.isha:
        return (Icons.nights_stay_rounded, const Color(0xFF8B5CF6));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconFor(prayer);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: enabled ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: enabled
                    ? color
                    : color.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    prayer.arabicName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? cs.onSurfaceVariant
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              onChanged: (_) => onToggle(),
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advance reminder time picker
// ─────────────────────────────────────────────────────────────────────────────

class _ReminderTimePicker extends StatelessWidget {
  const _ReminderTimePicker({
    required this.selected,
    required this.cs,
    required this.onSelect,
  });

  final int selected;
  final ColorScheme cs;
  final void Function(int minutes) onSelect;

  static const List<(int, String)> _options = [
    (0, 'On Time'),
    (5, '5 min'),
    (10, '10 min'),
    (15, '15 min'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (minutes, label) in _options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(minutes),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == minutes
                      ? const Color(0xFFF59E0B)
                      : cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == minutes
                        ? const Color(0xFFF59E0B)
                        : cs.outlineVariant,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected == minutes
                        ? Colors.white
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (minutes != 15) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Adhan type row
// ─────────────────────────────────────────────────────────────────────────────

class _AdhanTypeRow extends StatelessWidget {
  const _AdhanTypeRow({
    required this.adhanType,
    required this.selected,
    required this.cs,
    required this.onTap,
  });

  final AdhanType adhanType;
  final bool selected;
  final ColorScheme cs;
  final VoidCallback onTap;

  static (IconData, String) _metaFor(AdhanType t) {
    switch (t) {
      case AdhanType.standard:
        return (Icons.volume_up_rounded, 'Plays the adhan at prayer time');
      case AdhanType.silent:
        return (Icons.vibration_rounded, 'Vibration only — no sound');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, subtitle) = _metaFor(adhanType);
    const color = Color(0xFFF59E0B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.14)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? color : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    adhanType.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant, width: 1.5),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reliability section — battery optimisation + OEM auto-start guidance
// ─────────────────────────────────────────────────────────────────────────────

class _ReliabilitySection extends StatefulWidget {
  const _ReliabilitySection();

  @override
  State<_ReliabilitySection> createState() => _ReliabilitySectionState();
}

class _ReliabilitySectionState extends State<_ReliabilitySection> {
  bool? _batteryOptIgnored;

  @override
  void initState() {
    super.initState();
    _checkBatteryOpt();
  }

  Future<void> _checkBatteryOpt() async {
    final ignored = await NativeAlarmService.isBatteryOptimizationIgnored();
    if (mounted) setState(() => _batteryOptIgnored = ignored);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Battery optimisation card ──────────────────────────────────────
        _buildCard(
          context,
          cs: cs,
          isDark: isDark,
          icon: Icons.battery_saver_rounded,
          iconColor: _batteryOptIgnored == false
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
          title: 'Battery Optimisation',
          subtitle: _batteryOptIgnored == null
              ? 'Checking…'
              : _batteryOptIgnored!
                  ? 'Unrestricted — notifications will be reliable'
                  : 'Restricted — alarms may be delayed or missed',
          trailing: _batteryOptIgnored == false
              ? _FixButton(
                  label: 'Fix Now',
                  color: const Color(0xFFEF4444),
                  onTap: () async {
                    await NativeAlarmService.openBatteryOptimizationSettings();
                    // Re-check after the user returns from settings
                    await Future<void>.delayed(const Duration(seconds: 1));
                    _checkBatteryOpt();
                  },
                )
              : null,
        ),

        const SizedBox(height: 10),

        // ── Auto-start card ────────────────────────────────────────────────
        _buildCard(
          context,
          cs: cs,
          isDark: isDark,
          icon: Icons.rocket_launch_rounded,
          iconColor: const Color(0xFF6366F1),
          title: 'Auto-Start Permission',
          subtitle:
              'Required on Xiaomi, Infinix, OPPO & others\nto receive alarms when the app is closed.',
          trailing: _FixButton(
            label: 'Open',
            color: const Color(0xFF6366F1),
            onTap: () => NativeAlarmService.openAutoStartSettings(),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainer.withValues(alpha: 0.55)
            : cs.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  const _FixButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
