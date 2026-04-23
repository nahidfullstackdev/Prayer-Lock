import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

class IslamicCalendarScreen extends StatefulWidget {
  const IslamicCalendarScreen({super.key});

  @override
  State<IslamicCalendarScreen> createState() => _IslamicCalendarScreenState();
}

class _IslamicCalendarScreenState extends State<IslamicCalendarScreen> {
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final todayHijri = HijriCalendar.fromDate(today);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HeaderBar(
            title: 'Islamic Calendar',
            subtitle:
                '${_formatHijri(todayHijri)} · ${DateFormat('EEE, d MMM yyyy').format(today)}',
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _TodayCard(today: today, hijri: todayHijri),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _MonthCard(
                anchor: _anchor,
                today: today,
                onPrev: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 10),
              child: Text(
                'Key Islamic Dates',
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
              child: _UpcomingEventsCard(from: today),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatHijri(HijriCalendar h) =>
    '${h.hDay} ${h.longMonthName} ${h.hYear} AH';

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      elevation: 0,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Text(
          title,
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 12, 20, 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today Card ────────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today, required this.hijri});
  final DateTime today;
  final HijriCalendar hijri;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${hijri.hDay}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hijri.longMonthName} ${hijri.hYear} AH',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(today),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.mosque_rounded,
              color: cs.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Month Grid ────────────────────────────────────────────────────────────────

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.anchor,
    required this.today,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime anchor;
  final DateTime today;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final firstOfMonth = DateTime(anchor.year, anchor.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(anchor.year, anchor.month);
    // Sunday = 0, Monday = 1 … Saturday = 6
    final leadingBlanks = firstOfMonth.weekday % 7;

    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: Icon(Icons.chevron_left_rounded, color: cs.onSurface),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(anchor),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: Icon(Icons.chevron_right_rounded, color: cs.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Expanded(
                    child: _WeekdayLabel(label: d),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          for (int row = 0; row < rowCount; row++)
            Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayNum = cellIndex - leadingBlanks + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 52));
                }
                final date = DateTime(anchor.year, anchor.month, dayNum);
                final isToday = DateUtils.isSameDay(date, today);
                final hijriDay = HijriCalendar.fromDate(date).hDay;
                final isFriday = date.weekday == DateTime.friday;
                return Expanded(
                  child: _DayCell(
                    gregorian: dayNum,
                    hijri: hijriDay,
                    isToday: isToday,
                    isFriday: isFriday,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.gregorian,
    required this.hijri,
    required this.isToday,
    required this.isFriday,
  });

  final int gregorian;
  final int hijri;
  final bool isToday;
  final bool isFriday;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isToday ? cs.primary : Colors.transparent;
    final fg = isToday ? cs.onPrimary : cs.onSurface;
    final hijriColor = isToday
        ? cs.onPrimary.withValues(alpha: 0.8)
        : (isFriday ? cs.primary : cs.onSurfaceVariant);

    return Container(
      height: 52,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isFriday && !isToday
            ? Border.all(color: cs.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$gregorian',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$hijri',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: hijriColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Upcoming Events ───────────────────────────────────────────────────────────

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({required this.from});
  final DateTime from;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final events = _nextEvents(from);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          for (int i = 0; i < events.length; i++) ...[
            _EventRow(event: events[i]),
            if (i < events.length - 1)
              Divider(height: 1, indent: 68, color: cs.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final _IslamicEvent event;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysLeft = event.gregorian.difference(DateTime.now()).inDays;
    final daysLabel = daysLeft <= 0
        ? 'Today'
        : daysLeft == 1
            ? 'Tomorrow'
            : 'in $daysLeft days';

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
            child: Icon(event.icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.hijriDay} ${event.hijriMonthName} · ${DateFormat('d MMM yyyy').format(event.gregorian)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              daysLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslamicEvent {
  const _IslamicEvent({
    required this.name,
    required this.icon,
    required this.hijriMonth,
    required this.hijriMonthName,
    required this.hijriDay,
    required this.gregorian,
  });

  final String name;
  final IconData icon;
  final int hijriMonth;
  final String hijriMonthName;
  final int hijriDay;
  final DateTime gregorian;
}

/// Canonical Islamic observance dates, resolved to the nearest upcoming
/// Gregorian date relative to [from]. If a date has passed this Hijri year,
/// it rolls to the following Hijri year.
List<_IslamicEvent> _nextEvents(DateTime from) {
  const defs = <({int month, int day, String name, IconData icon})>[
    (month: 1, day: 1, name: 'Islamic New Year', icon: Icons.star_rounded),
    (month: 1, day: 10, name: 'Day of Ashura', icon: Icons.water_drop_rounded),
    (
      month: 3,
      day: 12,
      name: 'Mawlid an-Nabi',
      icon: Icons.auto_awesome_rounded,
    ),
    (
      month: 7,
      day: 27,
      name: 'Isra & Mi\'raj',
      icon: Icons.nightlight_round,
    ),
    (
      month: 8,
      day: 15,
      name: 'Laylat al-Bara\'at',
      icon: Icons.brightness_2_rounded,
    ),
    (
      month: 9,
      day: 1,
      name: 'First Day of Ramadan',
      icon: Icons.mosque_rounded,
    ),
    (
      month: 9,
      day: 27,
      name: 'Laylat al-Qadr',
      icon: Icons.brightness_7_rounded,
    ),
    (month: 10, day: 1, name: 'Eid al-Fitr', icon: Icons.celebration_rounded),
    (month: 12, day: 9, name: 'Day of Arafah', icon: Icons.terrain_rounded),
    (
      month: 12,
      day: 10,
      name: 'Eid al-Adha',
      icon: Icons.celebration_rounded,
    ),
  ];

  final hijriNow = HijriCalendar.fromDate(from);
  final converter = HijriCalendar();

  final events = <_IslamicEvent>[];
  for (final d in defs) {
    int year = hijriNow.hYear;
    DateTime greg = converter.hijriToGregorian(year, d.month, d.day);
    if (greg.isBefore(DateTime(from.year, from.month, from.day))) {
      year += 1;
      greg = converter.hijriToGregorian(year, d.month, d.day);
    }
    events.add(
      _IslamicEvent(
        name: d.name,
        icon: d.icon,
        hijriMonth: d.month,
        hijriMonthName: _hijriMonthName(d.month),
        hijriDay: d.day,
        gregorian: greg,
      ),
    );
  }
  events.sort((a, b) => a.gregorian.compareTo(b.gregorian));
  return events;
}

String _hijriMonthName(int month) {
  const names = [
    'Muharram',
    'Safar',
    'Rabi al-Awwal',
    'Rabi al-Thani',
    'Jumada al-Awwal',
    'Jumada al-Thani',
    'Rajab',
    'Sha\'ban',
    'Ramadan',
    'Shawwal',
    'Dhu al-Qi\'dah',
    'Dhu al-Hijjah',
  ];
  return names[(month - 1).clamp(0, 11)];
}
