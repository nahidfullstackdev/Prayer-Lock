import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/location_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/qibla_notifier.dart';

/// Shows the Qibla compass as a modal bottom sheet.
void showQiblaSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QiblaCompassSheet(),
  );
}

class QiblaCompassSheet extends ConsumerStatefulWidget {
  const QiblaCompassSheet({super.key});

  @override
  ConsumerState<QiblaCompassSheet> createState() => _QiblaCompassSheetState();
}

class _QiblaCompassSheetState extends ConsumerState<QiblaCompassSheet> {
  @override
  void initState() {
    super.initState();
    final location = ref.read(locationProvider).location;
    if (location != null) {
      ref.read(qiblaProvider.notifier).fetch(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final qiblaState = ref.watch(qiblaProvider);
    final locationState = ref.watch(locationProvider);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: cs.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qibla Direction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      locationState.location?.cityName ??
                          locationState.location?.countryName ??
                          'Your location',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Compass with live stream
          StreamBuilder<QiblahDirection>(
            stream: FlutterQiblah.qiblahStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildCompassError(cs);
              }

              final direction = snapshot.data?.direction ?? 0.0;
              final isFacingQibla = snapshot.hasData && direction.abs() < 10.0;

              return Column(
                children: [
                  _CompassWidget(direction: direction, cs: cs, isDark: isDark),
                  const SizedBox(height: 20),
                  // "Facing Qibla" badge
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child:
                        isFacingQibla
                            ? Container(
                              key: const ValueKey('aligned'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: cs.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: cs.primary,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Facing Qibla',
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : const SizedBox(
                              key: ValueKey('not-aligned'),
                              height: 36,
                            ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Distance card
          _buildDistanceRow(cs, qiblaState, locationState),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildDistanceRow(
    ColorScheme cs,
    QiblaState qiblaState,
    LocationState locationState,
  ) {
    if (qiblaState.isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
        ),
      );
    }

    if (qiblaState.qiblaDirection != null) {
      final distanceKm = qiblaState.qiblaDirection!.distance.toStringAsFixed(0);
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mosque_rounded, size: 18, color: cs.secondary),
            const SizedBox(width: 10),
            Text(
              '$distanceKm km from the Holy Kaaba',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      );
    }

    if (locationState.location == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Enable location to calculate distance to Mecca',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompassError(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.explore_off_rounded,
            size: 52,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Compass not available on this device',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ─── Compass Widget ───────────────────────────────────────────────────────────

class _CompassWidget extends StatefulWidget {
  final double direction;
  final ColorScheme cs;
  final bool isDark;

  const _CompassWidget({
    required this.direction,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<_CompassWidget> {
  double _turns = 0;
  bool _initialized = false;

  @override
  void didUpdateWidget(_CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction) {
      _updateTurns(widget.direction);
    }
  }

  /// Shortest-path interpolation to avoid 359° → 1° spinning all the way around.
  void _updateTurns(double newDirection) {
    final targetTurns = newDirection / 360;
    if (!_initialized) {
      _turns = targetTurns;
      _initialized = true;
      setState(() {});
      return;
    }
    // Delta in turns, clamped to [-0.5, 0.5] (shorter arc).
    var delta = targetTurns - (_turns % 1.0);
    if (delta > 0.5) delta -= 1.0;
    if (delta < -0.5) delta += 1.0;
    setState(() => _turns += delta);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.isDark ? const Color(0xFF152032) : const Color(0xFFF5F2EB);

    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
          ),
          // Ring + tick marks + cardinal letters (static)
          CustomPaint(
            size: const Size(240, 240),
            painter: _CompassFacePainter(cs: widget.cs),
          ),
          // Rotating needle
          AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: const Size(240, 240),
              painter: _NeedlePainter(cs: widget.cs),
            ),
          ),
          // Center cap
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.cs.primary,
              border: Border.all(color: bgColor, width: 2.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compass Face Painter (static) ───────────────────────────────────────────

class _CompassFacePainter extends CustomPainter {
  final ColorScheme cs;

  _CompassFacePainter({required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.86;

    // Outer ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = cs.outlineVariant.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Tick marks
    for (int deg = 0; deg < 360; deg += 10) {
      final isCardinal = deg % 90 == 0;
      final isMajor = deg % 45 == 0;
      final tickLen =
          isCardinal
              ? 14.0
              : isMajor
              ? 9.0
              : 4.0;
      final angle = (deg - 90) * math.pi / 180;

      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - tickLen) * math.cos(angle),
        center.dy + (radius - tickLen) * math.sin(angle),
      );

      canvas.drawLine(
        outer,
        inner,
        Paint()
          ..color =
              isCardinal
                  ? cs.onSurface.withValues(alpha: 0.55)
                  : cs.onSurface.withValues(alpha: 0.15)
          ..strokeWidth = isCardinal ? 2.0 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Cardinal direction labels (N, S, E, W)
    final labelRadius = radius - 26;
    _drawLabel(
      canvas,
      'N',
      center + Offset(0, -labelRadius),
      cs.primary,
      bold: true,
    );
    _drawLabel(
      canvas,
      'S',
      center + Offset(0, labelRadius),
      cs.onSurfaceVariant,
    );
    _drawLabel(
      canvas,
      'E',
      center + Offset(labelRadius, 0),
      cs.onSurfaceVariant,
    );
    _drawLabel(
      canvas,
      'W',
      center + Offset(-labelRadius, 0),
      cs.onSurfaceVariant,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CompassFacePainter old) => false;
}

// ─── Needle Painter (rotates) ─────────────────────────────────────────────────

class _NeedlePainter extends CustomPainter {
  final ColorScheme cs;

  _NeedlePainter({required this.cs});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final halfH = size.height / 2;

    // Green tip (points toward Qibla = UP when direction == 0)
    final greenPath =
        Path()
          ..moveTo(cx, cy - halfH * 0.60) // tip
          ..lineTo(cx - 8, cy) // left base
          ..lineTo(cx + 8, cy) // right base
          ..close();

    canvas.drawPath(
      greenPath,
      Paint()
        ..color = cs.primary
        ..style = PaintingStyle.fill,
    );

    // Subtle highlight on the green half
    canvas.drawPath(
      greenPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(
          Rect.fromLTWH(cx - 8, cy - halfH * 0.60, 16, halfH * 0.60),
        ),
    );

    // Gray base (opposite end)
    final grayPath =
        Path()
          ..moveTo(cx, cy + halfH * 0.36) // base tip
          ..lineTo(cx - 6, cy) // left
          ..lineTo(cx + 6, cy) // right
          ..close();

    canvas.drawPath(
      grayPath,
      Paint()..color = cs.onSurface.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter _) => false;
}
