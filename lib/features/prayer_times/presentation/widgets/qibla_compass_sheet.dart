import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/utils/qibla_math.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

/// Shows the Qibla compass as a modal bottom sheet.
void showQiblaSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QiblaCompassSheet(),
  );
}

class QiblaCompassSheet extends ConsumerWidget {
  const QiblaCompassSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final location = ref.watch(locationProvider).location;

    // Qibla bearing and distance are pure functions of the user's location.
    // The moment locationProvider emits a location, both are available —
    // no async, no spinner, no notifier needed.
    final qiblaBearing = location == null
        ? null
        : QiblaMath.calculateQiblaBearing(
            location.latitude,
            location.longitude,
          );
    final distanceKm = location == null
        ? null
        : QiblaMath.distanceToKaabaKm(location.latitude, location.longitude);

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                      location?.cityName ??
                          location?.countryName ??
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
          StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildCompassError(cs);
              }

              final deviceHeading = snapshot.data?.heading ?? 0.0;
              final needleRotation = qiblaBearing == null
                  ? 0.0
                  : (qiblaBearing - deviceHeading + 360) % 360;
              // Dial counter-rotates so N stays anchored to real north.
              final faceRotation = (360 - deviceHeading) % 360;
              final isFacingQibla = snapshot.hasData &&
                  snapshot.data?.heading != null &&
                  qiblaBearing != null &&
                  (needleRotation < 10.0 || needleRotation > 350.0);

              return Column(
                children: [
                  _CompassWidget(
                    rotationDeg: needleRotation,
                    faceRotationDeg: faceRotation,
                    cs: cs,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),
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
          _buildDistanceRow(cs, distanceKm, location),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildDistanceRow(
    ColorScheme cs,
    double? distanceKm,
    LocationData? location,
  ) {
    if (distanceKm != null) {
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
              '${distanceKm.toStringAsFixed(0)} km from the Holy Kaaba',
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

    if (location == null) {
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
  /// Degrees the needle should point, measured clockwise from straight up.
  final double rotationDeg;

  /// Degrees the dial (ring + ticks + N/S/E/W labels) should rotate so that
  /// N stays anchored to real north. Typically `(360 − deviceHeading) % 360`.
  final double faceRotationDeg;

  final ColorScheme cs;
  final bool isDark;

  const _CompassWidget({
    required this.rotationDeg,
    required this.faceRotationDeg,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_CompassWidget> createState() => _CompassWidgetState();
}

class _CompassWidgetState extends State<_CompassWidget> {
  double _needleTurns = 0;
  double _faceTurns = 0;
  bool _needleInitialized = false;
  bool _faceInitialized = false;

  @override
  void didUpdateWidget(_CompassWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rotationDeg != widget.rotationDeg) {
      setState(() {
        final result = _stepTurns(
          _needleTurns,
          _needleInitialized,
          widget.rotationDeg,
        );
        _needleTurns = result.turns;
        _needleInitialized = true;
      });
    }
    if (oldWidget.faceRotationDeg != widget.faceRotationDeg) {
      setState(() {
        final result = _stepTurns(
          _faceTurns,
          _faceInitialized,
          widget.faceRotationDeg,
        );
        _faceTurns = result.turns;
        _faceInitialized = true;
      });
    }
  }

  /// Shortest-path interpolation to avoid 359° → 1° spinning all the way around.
  /// On the first update, snaps directly to the target.
  ({double turns}) _stepTurns(
    double currentTurns,
    bool initialized,
    double targetDeg,
  ) {
    final targetTurns = targetDeg / 360;
    if (!initialized) {
      return (turns: targetTurns);
    }
    var delta = targetTurns - (currentTurns % 1.0);
    if (delta > 0.5) delta -= 1.0;
    if (delta < -0.5) delta += 1.0;
    return (turns: currentTurns + delta);
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
          Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
          ),
          AnimatedRotation(
            turns: _faceTurns,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: const Size(240, 240),
              painter: _CompassFacePainter(cs: widget.cs),
            ),
          ),
          AnimatedRotation(
            turns: _needleTurns,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: const Size(240, 240),
              painter: _NeedlePainter(cs: widget.cs),
            ),
          ),
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

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = cs.outlineVariant.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

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

    // Tip sits slightly lower than before to leave room for the Kaaba icon.
    final tipY = cy - halfH * 0.52;

    final greenPath =
        Path()
          ..moveTo(cx, tipY)
          ..lineTo(cx - 8, cy)
          ..lineTo(cx + 8, cy)
          ..close();

    canvas.drawPath(
      greenPath,
      Paint()
        ..color = cs.primary
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      greenPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent],
        ).createShader(Rect.fromLTWH(cx - 8, tipY, 16, cy - tipY)),
    );

    final grayPath =
        Path()
          ..moveTo(cx, cy + halfH * 0.36)
          ..lineTo(cx - 6, cy)
          ..lineTo(cx + 6, cy)
          ..close();

    canvas.drawPath(
      grayPath,
      Paint()..color = cs.onSurface.withValues(alpha: 0.2),
    );

    _paintKaaba(canvas, Offset(cx, tipY));
  }

  /// Paints a stylized miniature Kaaba whose bottom edge sits at [tip].
  void _paintKaaba(Canvas canvas, Offset tip) {
    const cubeSize = 22.0;
    const gap = 2.0;
    final cube = Rect.fromLTWH(
      tip.dx - cubeSize / 2,
      tip.dy - cubeSize - gap,
      cubeSize,
      cubeSize,
    );
    final rrect = RRect.fromRectAndRadius(cube, const Radius.circular(2.5));

    canvas.drawRRect(
      rrect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF1A1A1A),
    );

    final bandTop = cube.top + cubeSize * 0.22;
    final band = Rect.fromLTWH(cube.left, bandTop, cubeSize, 3.0);
    canvas.drawRect(
      band,
      Paint()..color = const Color(0xFFD4AF37),
    );

    final door = Rect.fromLTWH(
      cube.right - 4.5,
      cube.top + cubeSize * 0.5,
      1.8,
      cubeSize * 0.4,
    );
    canvas.drawRect(
      door,
      Paint()..color = const Color(0xFFD4AF37),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = cs.onSurface.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_NeedlePainter _) => false;
}
