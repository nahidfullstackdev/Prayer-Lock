import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class RamadanTrackerScreen extends StatelessWidget {
  const RamadanTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final info = _RamadanInfo.resolve(today);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            elevation: 0,
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              title: Text(
                'Ramadan Tracker',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, cs.tertiary],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _StatusCard(info: info),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _DatesCard(info: info),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text(
                'Daily Reminders',
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
              child: _RemindersCard(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ramadan resolution ────────────────────────────────────────────────────────

enum _RamadanPhase { before, during, after }

class _RamadanInfo {
  const _RamadanInfo({
    required this.phase,
    required this.startGregorian,
    required this.endGregorian,
    required this.hijriYear,
    required this.currentDay,
    required this.totalDays,
    required this.daysUntil,
  });

  final _RamadanPhase phase;
  final DateTime startGregorian;
  final DateTime endGregorian;
  final int hijriYear;
  final int currentDay;
  final int totalDays;
  final int daysUntil;

  static _RamadanInfo resolve(DateTime today) {
    final converter = HijriCalendar();
    final hijriToday = HijriCalendar.fromDate(today);

    int year = hijriToday.hYear;
    DateTime start = converter.hijriToGregorian(year, 9, 1);

    // Total days in Ramadan for this Hijri year (29 or 30)
    int totalDays = _daysInHijriMonth(year, 9);
    DateTime end = start.add(Duration(days: totalDays - 1));

    final dateOnly = DateTime(today.year, today.month, today.day);

    if (dateOnly.isBefore(start)) {
      return _RamadanInfo(
        phase: _RamadanPhase.before,
        startGregorian: start,
        endGregorian: end,
        hijriYear: year,
        currentDay: 0,
        totalDays: totalDays,
        daysUntil: dateOnly.difference(start).inDays.abs(),
      );
    }
    if (!dateOnly.isAfter(end)) {
      final day = dateOnly.difference(start).inDays + 1;
      return _RamadanInfo(
        phase: _RamadanPhase.during,
        startGregorian: start,
        endGregorian: end,
        hijriYear: year,
        currentDay: day,
        totalDays: totalDays,
        daysUntil: 0,
      );
    }

    // Ramadan for this Hijri year has ended → roll to next Hijri year
    year += 1;
    start = converter.hijriToGregorian(year, 9, 1);
    totalDays = _daysInHijriMonth(year, 9);
    end = start.add(Duration(days: totalDays - 1));
    return _RamadanInfo(
      phase: _RamadanPhase.before,
      startGregorian: start,
      endGregorian: end,
      hijriYear: year,
      currentDay: 0,
      totalDays: totalDays,
      daysUntil: dateOnly.difference(start).inDays.abs(),
    );
  }
}

int _daysInHijriMonth(int year, int month) {
  final converter = HijriCalendar();
  final firstOfThis = converter.hijriToGregorian(year, month, 1);
  final nextYear = month == 12 ? year + 1 : year;
  final nextMonth = month == 12 ? 1 : month + 1;
  final firstOfNext = converter.hijriToGregorian(nextYear, nextMonth, 1);
  return firstOfNext.difference(firstOfThis).inDays;
}

// ── Cards ─────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.info});
  final _RamadanInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String heading;
    final String big;
    final String sub;
    final double? progress;

    switch (info.phase) {
      case _RamadanPhase.before:
        heading = 'Ramadan Approaches';
        big = info.daysUntil == 0 ? 'Tomorrow' : '${info.daysUntil}';
        sub = info.daysUntil == 0
            ? 'Prepare your intention for tomorrow'
            : 'days until Ramadan ${info.hijriYear} AH';
        progress = null;
        break;
      case _RamadanPhase.during:
        heading = 'Ramadan Mubarak';
        big = 'Day ${info.currentDay}';
        sub = 'of ${info.totalDays} · Ramadan ${info.hijriYear} AH';
        progress = info.currentDay / info.totalDays;
        break;
      case _RamadanPhase.after:
        heading = 'Ramadan Ended';
        big = '—';
        sub = 'Until next year';
        progress = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.15),
            cs.tertiary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mosque_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                heading,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            big,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          if (progress != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}% complete',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DatesCard extends StatelessWidget {
  const _DatesCard({required this.info});
  final _RamadanInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final format = DateFormat('EEE, d MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          _DateRow(
            icon: Icons.flag_rounded,
            label: 'First Fast',
            value: format.format(info.startGregorian),
          ),
          Divider(height: 1, indent: 68, color: cs.outlineVariant),
          _DateRow(
            icon: Icons.nightlight_round,
            label: 'Laylat al-Qadr (likely)',
            value: format.format(
              info.startGregorian.add(const Duration(days: 26)),
            ),
          ),
          Divider(height: 1, indent: 68, color: cs.outlineVariant),
          _DateRow(
            icon: Icons.event_available_rounded,
            label: 'Last Fast',
            value: format.format(info.endGregorian),
          ),
          Divider(height: 1, indent: 68, color: cs.outlineVariant),
          _DateRow(
            icon: Icons.celebration_rounded,
            label: 'Eid al-Fitr',
            value: format.format(
              info.endGregorian.add(const Duration(days: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const items = <({IconData icon, String title, String body})>[
      (
        icon: Icons.wb_twilight_rounded,
        title: 'Suhoor',
        body: 'Eat a light pre-dawn meal before Fajr. The Prophet ﷺ said there is blessing in it.',
      ),
      (
        icon: Icons.self_improvement_rounded,
        title: 'Guard the tongue',
        body: 'Fasting is not only from food. Avoid backbiting, arguing, and idle speech.',
      ),
      (
        icon: Icons.menu_book_rounded,
        title: 'Qur\'an recitation',
        body: 'Aim for one juz per day to complete the Qur\'an during the month.',
      ),
      (
        icon: Icons.volunteer_activism_rounded,
        title: 'Charity',
        body: 'Give generously — the Prophet ﷺ was most generous in Ramadan.',
      ),
      (
        icon: Icons.restaurant_rounded,
        title: 'Iftar',
        body: 'Break your fast with dates and water at Maghrib, then pray before a full meal.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _ReminderRow(
              icon: items[i].icon,
              title: items[i].title,
              body: items[i].body,
            ),
            if (i < items.length - 1)
              Divider(height: 1, indent: 68, color: cs.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: cs.secondary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
