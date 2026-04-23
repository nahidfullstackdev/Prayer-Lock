// ─── Complete Multi-Step Onboarding ──────────────────────────────────────────
//
// 18-step personalized flow: emotional hook → questions → permissions →
// processing → results → mandatory paywall.
//
// Navigation: PageView with NeverScrollableScrollPhysics; parent drives all
// transitions. No step can be skipped (except App Blocker which has "Skip
// for now"). The Paywall is hard — zero skip.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_lock/core/theme/app_theme.dart';
import 'package:prayer_lock/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:prayer_lock/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:prayer_lock/features/subscription/presentation/widgets/pro_paywall_sheet.dart';
import 'package:prayer_lock/main_screen.dart';

// ─── Page index constants ─────────────────────────────────────────────────────

const int _kProcessing = 12;
const int _kPlanReady = 13;
const int _kPaywall = 17;

// Maps page index → question number (only question-flow pages).
int? _questionNo(int page) =>
    const {2: 1, 3: 2, 5: 3, 6: 4, 7: 5, 8: 6, 9: 7}[page];

enum _Plan { monthly, lifetime }

// ─── OnboardingScreen ─────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  // ── User answers ─────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  String _name = '';
  String _phoneHoursKey = '';
  double _phoneHoursValue = 0;
  String _habitToChange = '';
  int _prayerCount = -1;
  String _relationship = '';
  String _obstacle = '';
  String _screenBehavior = '';

  // ── Permission state ──────────────────────────────────────────────────────────
  bool _locationGranted = false;
  bool _requestingLocation = false;

  // ── Processing ────────────────────────────────────────────────────────────────
  double _processingProgress = 0;
  Timer? _processingTimer;

  // ── Paywall ───────────────────────────────────────────────────────────────────
  _Plan _selectedPlan = _Plan.lifetime;
  bool _paywallLoading = false;
  String? _paywallError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() => _name = _nameCtrl.text.trim()));
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _processingTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final s = await Permission.location.status;
    if (mounted) setState(() => _locationGranted = s.isGranted);
  }

  // ─── Navigation ──────────────────────────────────────────────────────────────

  void _goTo(int page) {
    _ctrl.animateToPage(
      page,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _page = page);
    if (page == _kProcessing) _startProcessing();
  }

  void _next() => _goTo(_page + 1);
  void _back() => _goTo(_page - 1);

  // ─── Processing ───────────────────────────────────────────────────────────────

  void _startProcessing() {
    _processingProgress = 0;
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(const Duration(milliseconds: 55), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _processingProgress += 0.03);
      if (_processingProgress >= 1.0) {
        _processingProgress = 1.0;
        t.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _goTo(_kPlanReady);
        });
      }
    });
  }

  // ─── Location permission ──────────────────────────────────────────────────────

  Future<void> _requestLocation() async {
    setState(() => _requestingLocation = true);
    try {
      final s = await Permission.location.request();
      if (mounted) {
        setState(() => _locationGranted = s.isGranted);
        if (s.isGranted) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) _next();
        }
      }
    } finally {
      if (mounted) setState(() => _requestingLocation = false);
    }
  }

  // ─── Purchase ─────────────────────────────────────────────────────────────────

  Future<void> _handlePurchase() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    setState(() {
      _paywallLoading = true;
      _paywallError = null;
    });
    try {
      await showProPaywall(context, repo, placement: 'onboarding_paywall');
      if (!mounted) return;
      if (ref.read(isProProvider)) await _finish();
    } catch (_) {
      if (mounted) setState(() => _paywallError = 'Purchase failed. Please try again.');
    } finally {
      if (mounted) setState(() => _paywallLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final repo = ref.read(subscriptionRepositoryProvider);
    setState(() {
      _paywallLoading = true;
      _paywallError = null;
    });
    try {
      await repo.restorePurchases();
      if (!mounted) return;
      if (ref.read(isProProvider)) {
        await _finish();
      } else {
        if (mounted) setState(() => _paywallError = 'No active subscription found.');
      }
    } catch (_) {
      if (mounted) setState(() => _paywallError = 'Restore failed. Please try again.');
    } finally {
      if (mounted) setState(() => _paywallLoading = false);
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingNotifierProvider).complete();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, anim, __) =>
            FadeTransition(opacity: anim, child: const MainScreen()),
      ),
    );
  }


  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final qNo = _questionNo(_page);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1520),
        body: Stack(
          children: [
            const _OBBackground(),
            Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: _buildTopBar(qNo),
                ),
                Expanded(
                  child: PageView(
                    controller: _ctrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _buildPages(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(int? qNo) {
    final showBack = _page > 0 && _page != _kPaywall;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: showBack ? _back : null,
              child: AnimatedOpacity(
                opacity: showBack ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF152032),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFF253550)),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF8899AD),
                    size: 15,
                  ),
                ),
              ),
            ),

            // Progress section (question flow only)
            if (qNo != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question $qNo of 7',
                      style: const TextStyle(
                        color: Color(0xFF8899AD),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: qNo / 7.0,
                        backgroundColor: const Color(0xFF1E2D44),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ] else
              const Spacer(),

            const SizedBox(width: 38), // balance right side
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages() {
    final displayName = _name.isEmpty ? 'you' : _name;
    return [
      // 0 — Intro
      _IntroPage(onNext: _next),
      // 1 — Personalization intro
      _PersonalizeIntroPage(onNext: _next),
      // 2 — Q1: Name
      _AskNamePage(controller: _nameCtrl, canAdvance: _name.isNotEmpty, onNext: _next),
      // 3 — Q2: Phone time
      _AskPhoneTimePage(
        selected: _phoneHoursKey,
        onSelect: (key, val) {
          setState(() {
            _phoneHoursKey = key;
            _phoneHoursValue = val;
          });
          Future.delayed(const Duration(milliseconds: 250), _next);
        },
      ),
      // 4 — Phone shock
      _PhoneShockPage(phoneHoursValue: _phoneHoursValue, onNext: _next),
      // 5 — Q3: Habit
      _AskHabitPage(
        name: displayName,
        selected: _habitToChange,
        onSelect: (v) {
          setState(() => _habitToChange = v);
          Future.delayed(const Duration(milliseconds: 250), _next);
        },
      ),
      // 6 — Q4: Prayer count
      _AskPrayerCountPage(
        selected: _prayerCount,
        onSelect: (v) => setState(() => _prayerCount = v),
        canAdvance: _prayerCount >= 0,
        onNext: _next,
      ),
      // 7 — Q5: Relationship
      _AskRelationshipPage(
        name: displayName,
        selected: _relationship,
        onSelect: (v) {
          setState(() => _relationship = v);
          Future.delayed(const Duration(milliseconds: 250), _next);
        },
      ),
      // 8 — Q6: Obstacle
      _AskObstaclePage(
        selected: _obstacle,
        onSelect: (v) {
          setState(() => _obstacle = v);
          Future.delayed(const Duration(milliseconds: 250), _next);
        },
      ),
      // 9 — Q7: Doom scroll
      _AskDoomScrollPage(
        selected: _screenBehavior,
        onSelect: (v) {
          setState(() => _screenBehavior = v);
          Future.delayed(const Duration(milliseconds: 250), _next);
        },
      ),
      // 10 — Thank you
      _ThankYouPage(name: displayName, onNext: _next),
      // 11 — Location permission
      _LocationPage(
        granted: _locationGranted,
        requesting: _requestingLocation,
        onRequestLocation: _requestLocation,
        onSkip: _next,
        onNext: _next,
      ),
      // 12 — Processing
      _ProcessingPage(progress: _processingProgress, name: displayName),
      // 13 — Plan ready
      _PlanReadyPage(name: displayName, onNext: _next),
      // 14 — Results
      _ResultsPage(
        name: displayName,
        phoneHoursKey: _phoneHoursKey,
        phoneHoursValue: _phoneHoursValue,
        prayerCount: _prayerCount,
        onNext: _next,
      ),
      // 15 — Features
      _FeaturesPage(onNext: _next),
      // 16 — App blocker permission
      _AppBlockerPage(onNext: _next, onSkip: _next),
      // 17 — Paywall (mandatory)
      _PaywallPage(
        selectedPlan: _selectedPlan,
        onPlanSelect: (p) => setState(() => _selectedPlan = p),
        isLoading: _paywallLoading,
        errorMessage: _paywallError,
        onPurchase: _handlePurchase,
        onRestore: _handleRestore,
        onDebugSkip: kDebugMode ? _finish : null,
      ),
    ];
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

class _OBBackground extends StatelessWidget {
  const _OBBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(painter: _StarfieldPainter()),
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = const Color(0xFF1E2D44);
    for (int i = 0; i < 60; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.3;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => false;
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _QScrollable extends StatelessWidget {
  const _QScrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: child,
    );
  }
}

class _QHeader extends StatelessWidget {
  const _QHeader({required this.question, this.subtitle});
  final String question;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE8EDF4),
            height: 1.3,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF8899AD),
              height: 1.55,
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.emerald.withValues(alpha: 0.10)
              : const Color(0xFF152032),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.emerald : const Color(0xFF253550),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFFE8EDF4)
                      : const Color(0xFFBBC8D8),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.emerald : Colors.transparent,
                border: Border.all(
                  color: selected ? AppTheme.emerald : const Color(0xFF253550),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppTheme.emerald;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.3),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowIcon extends StatelessWidget {
  const _GlowIcon({
    required this.icon,
    this.color = AppTheme.emerald,
    this.size = 88,
    this.iconSize = 42,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.35,
      height: size * 1.35,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.35,
            height: size * 1.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF152032),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ],
      ),
    );
  }
}

class _GlowLogo extends StatelessWidget {
  const _GlowLogo({this.size = 110});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.emerald.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Image.asset(
            'assets/images/logo/prayer-lock-icon.png',
            width: size,
            height: size,
            filterQuality: FilterQuality.high,
          ),
        ],
      ),
    );
  }
}

// ─── Page 0: Intro ────────────────────────────────────────────────────────────

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const _GlowLogo(size: 110),
                const SizedBox(height: 20),
                const Text(
                  'بِسْمِ ٱللَّٰهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: TextStyle(
                    fontSize: 19,
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Prayer Lock',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8EDF4),
                    letterSpacing: -1.5,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    'Build Discipline. Pray on Time.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emerald,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Text(
                    '"Ever feel your phone gets more\nattention than Allah?"',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gold,
                      height: 1.45,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'You are not alone.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8EDF4),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Distractions are everywhere, quietly pulling you away from the peace you\'re looking for.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'Yes, I Want to Change',
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

// ─── Page 1: Personalization Intro ────────────────────────────────────────────

class _PersonalizeIntroPage extends StatelessWidget {
  const _PersonalizeIntroPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GlowIcon(
                  icon: Icons.tune_rounded,
                  color: AppTheme.teal,
                  size: 76,
                  iconSize: 36,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Let's customize\nPrayer Lock for you",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8EDF4),
                    height: 1.2,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'We\'ll ask you a few honest questions about your life. No judgement — just clarity.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _buildTopic(
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFFEF4444),
                  label: 'Your current phone habits',
                ),
                const SizedBox(height: 12),
                _buildTopic(
                  icon: Icons.self_improvement_rounded,
                  color: AppTheme.emerald,
                  label: 'Your relationship with prayer',
                ),
                const SizedBox(height: 12),
                _buildTopic(
                  icon: Icons.flag_rounded,
                  color: AppTheme.gold,
                  label: 'Your personal discipline goals',
                ),
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152032),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF253550)),
                  ),
                  child: const Text(
                    'We\'re building a system that fits your life — not a generic plan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBBC8D8),
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: "Let's Start",
            icon: Icons.arrow_forward_rounded,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }

  Widget _buildTopic({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFCDD5E0),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 18),
      ],
    );
  }
}

// ─── Page 2: Ask Name ─────────────────────────────────────────────────────────

class _AskNamePage extends StatelessWidget {
  const _AskNamePage({
    required this.controller,
    required this.canAdvance,
    required this.onNext,
  });

  final TextEditingController controller;
  final bool canAdvance;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: _QScrollable(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const _QHeader(
                  question: 'What should we call you?',
                  subtitle:
                      'We\'ll personalize your plan with your name throughout the experience.',
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF4),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: AppTheme.emerald,
                  decoration: InputDecoration(
                    hintText: 'Your first name',
                    hintStyle: const TextStyle(
                      color: Color(0xFF5A6D85),
                      fontSize: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF152032),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF253550)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.emerald,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                  ),
                  onSubmitted: canAdvance ? (_) => onNext() : null,
                ),
                if (controller.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.emerald.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.waving_hand_rounded,
                          color: AppTheme.gold,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Assalamu Alaikum, ${controller.text.trim()}! We\'re glad you\'re here.',
                            style: const TextStyle(
                              color: Color(0xFFCDD5E0),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: canAdvance ? onNext : null,
          ),
        ),
      ],
    );
  }
}

// ─── Page 3: Ask Phone Time ───────────────────────────────────────────────────

class _AskPhoneTimePage extends StatelessWidget {
  const _AskPhoneTimePage({required this.selected, required this.onSelect});

  final String selected;
  final void Function(String key, double value) onSelect;

  static const _options = [
    (key: 'Less than 1 hour', value: 0.5, emoji: '😇'),
    (key: '1 – 2 hours', value: 1.5, emoji: '😌'),
    (key: '2 – 4 hours', value: 3.0, emoji: '😬'),
    (key: '4 – 6 hours', value: 5.0, emoji: '😰'),
    (key: '6+ hours', value: 7.0, emoji: '😱'),
  ];

  @override
  Widget build(BuildContext context) {
    return _QScrollable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _QHeader(
            question: 'How much time do you spend on your phone daily?',
            subtitle: 'Include social media, videos, browsing — all screen time.',
          ),
          const SizedBox(height: 24),
          ..._options.map(
            (o) => _OptionTile(
              emoji: o.emoji,
              label: o.key,
              selected: selected == o.key,
              onTap: () => onSelect(o.key, o.value),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 4: Phone Shock ──────────────────────────────────────────────────────

class _PhoneShockPage extends StatelessWidget {
  const _PhoneShockPage({required this.phoneHoursValue, required this.onNext});

  final double phoneHoursValue;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final yearlyHours = (phoneHoursValue * 365).round();
    final yearlyDays = (yearlyHours / 24.0).toStringAsFixed(1);
    final yearlyWeeks = (yearlyHours / (24.0 * 7)).toStringAsFixed(1);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                const _GlowIcon(
                  icon: Icons.access_time_rounded,
                  color: Color(0xFFEF4444),
                  size: 80,
                  iconSize: 38,
                ),
                const SizedBox(height: 24),
                const Text(
                  'The Truth About Your Time',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EDF4),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFEF4444).withValues(alpha: 0.12),
                        const Color(0xFFEF4444).withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$yearlyHours',
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEF4444),
                          height: 1.0,
                          letterSpacing: -3,
                        ),
                      ),
                      const Text(
                        'hours per year',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF8899AD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ShockStat(label: 'Days/year', value: yearlyDays),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ShockStat(label: 'Weeks/year', value: yearlyWeeks),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Every hour on your phone is an hour away from Allah, from your family, from your purpose.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    'In $yearlyHours hours you could have:\n'
                    '• Recited the entire Quran ${(yearlyHours ~/ 9)} times\n'
                    '• Prayed Fajr ${(yearlyHours * 4).round()} extra rakats\n'
                    '• Built a life-changing habit',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFBBC8D8),
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'This Has to Change',
            onPressed: onNext,
            color: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _ShockStat extends StatelessWidget {
  const _ShockStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF152032),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF253550)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8EDF4),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8899AD),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 5: Ask Habit ────────────────────────────────────────────────────────

class _AskHabitPage extends StatelessWidget {
  const _AskHabitPage({
    required this.name,
    required this.selected,
    required this.onSelect,
  });

  final String name;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _opts = [
    (v: 'Social media', e: '📱'),
    (v: 'YouTube / videos', e: '▶️'),
    (v: 'Games / entertainment', e: '🎮'),
    (v: 'Doom-scrolling news', e: '📰'),
    (v: 'Messaging / chats', e: '💬'),
    (v: 'All of the above', e: '😅'),
  ];

  @override
  Widget build(BuildContext context) {
    return _QScrollable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _QHeader(
            question: 'What habit do you most want to break?',
            subtitle: 'Be specific, $name — the plan works better when we know the enemy.',
          ),
          const SizedBox(height: 24),
          ..._opts.map(
            (o) => _OptionTile(
              emoji: o.e,
              label: o.v,
              selected: selected == o.v,
              onTap: () => onSelect(o.v),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 6: Ask Prayer Count ─────────────────────────────────────────────────

class _AskPrayerCountPage extends StatelessWidget {
  const _AskPrayerCountPage({
    required this.selected,
    required this.onSelect,
    required this.canAdvance,
    required this.onNext,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final bool canAdvance;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: _QScrollable(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const _QHeader(
                  question: 'How many times do you currently pray each day?',
                  subtitle:
                      'Be honest — this helps us build a realistic plan. Allah knows anyway. 🙂',
                ),
                const SizedBox(height: 32),
                Center(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          key: ValueKey<int>(selected),
                          selected < 0 ? '?' : '$selected',
                          style: TextStyle(
                            fontSize: 80,
                            fontWeight: FontWeight.w900,
                            color: selected < 0
                                ? const Color(0xFF253550)
                                : AppTheme.emerald,
                            height: 1.0,
                            letterSpacing: -3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected == 1 ? 'prayer per day' : 'prayers per day',
                        style: const TextStyle(
                          color: Color(0xFF8899AD),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    final sel = selected == i;
                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? AppTheme.emerald : const Color(0xFF152032),
                          border: Border.all(
                            color: sel ? AppTheme.emerald : const Color(0xFF253550),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : const Color(0xFF8899AD),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['None', '', '', '', '', 'All 5'].map((l) {
                    return SizedBox(
                      width: 48,
                      child: Text(
                        l,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF5A6D85),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: canAdvance ? onNext : null,
          ),
        ),
      ],
    );
  }
}

// ─── Page 7: Ask Relationship ─────────────────────────────────────────────────

class _AskRelationshipPage extends StatelessWidget {
  const _AskRelationshipPage({
    required this.name,
    required this.selected,
    required this.onSelect,
  });

  final String name;
  final String selected;
  final ValueChanged<String> onSelect;

  static const _opts = [
    (v: 'Very close — I pray consistently', e: '💚'),
    (v: 'Getting closer — making progress', e: '🌱'),
    (v: 'Feeling distant lately', e: '🌥️'),
    (v: 'Struggling to connect', e: '💔'),
    (v: 'Just starting my journey', e: '🌅'),
  ];

  @override
  Widget build(BuildContext context) {
    return _QScrollable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _QHeader(
            question: 'How would you describe your connection with Allah right now?',
            subtitle: 'This is a safe space, $name. No answer is wrong.',
          ),
          const SizedBox(height: 24),
          ..._opts.map(
            (o) => _OptionTile(
              emoji: o.e,
              label: o.v,
              selected: selected == o.v,
              onTap: () => onSelect(o.v),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 8: Ask Obstacle ─────────────────────────────────────────────────────

class _AskObstaclePage extends StatelessWidget {
  const _AskObstaclePage({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  static const _opts = [
    (v: 'I forget prayer times', e: '⏰'),
    (v: 'Phone distracts me', e: '📵'),
    (v: 'My schedule is too busy', e: '📆'),
    (v: 'Lack of motivation / discipline', e: '😴'),
    (v: 'I don\'t always know prayer times', e: '🕌'),
    (v: 'No one around me prays', e: '🧑‍🤝‍🧑'),
  ];

  @override
  Widget build(BuildContext context) {
    return _QScrollable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _QHeader(
            question: 'What is your biggest obstacle to praying on time?',
            subtitle:
                'Identifying the real obstacle is the first step to removing it.',
          ),
          const SizedBox(height: 24),
          ..._opts.map(
            (o) => _OptionTile(
              emoji: o.e,
              label: o.v,
              selected: selected == o.v,
              onTap: () => onSelect(o.v),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 9: Ask Doom Scroll ──────────────────────────────────────────────────

class _AskDoomScrollPage extends StatelessWidget {
  const _AskDoomScrollPage({required this.selected, required this.onSelect});

  final String selected;
  final ValueChanged<String> onSelect;

  static const _opts = [
    (v: 'Constantly — multiple times a day', e: '🔄'),
    (v: 'Often — at least once daily', e: '📲'),
    (v: 'Sometimes — when I\'m bored', e: '🤷'),
    (v: 'Rarely — I manage it well', e: '👍'),
    (v: 'Never — I\'m in control', e: '💪'),
  ];

  @override
  Widget build(BuildContext context) {
    return _QScrollable(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _QHeader(
            question: 'How often do you doom-scroll or mindlessly browse?',
            subtitle:
                'Opening Instagram "for a second" and losing 45 minutes — how familiar?',
          ),
          const SizedBox(height: 24),
          ..._opts.map(
            (o) => _OptionTile(
              emoji: o.e,
              label: o.v,
              selected: selected == o.v,
              onTap: () => onSelect(o.v),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 10: Thank You ───────────────────────────────────────────────────────

class _ThankYouPage extends StatelessWidget {
  const _ThankYouPage({required this.name, required this.onNext});
  final String name;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                const _GlowIcon(
                  icon: Icons.favorite_rounded,
                  color: AppTheme.gold,
                  size: 80,
                  iconSize: 38,
                ),
                const SizedBox(height: 24),
                Text(
                  'JazakAllah Khair,\n$name',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EDF4),
                    height: 1.25,
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for being honest with yourself. That takes courage.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppTheme.gold.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'إِنَّ اللَّهَ لَا يُغَيِّرُ مَا بِقَوْمٍ حَتَّىٰ يُغَيِّرُوا مَا بِأَنفُسِهِمْ',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.gold,
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        color: AppTheme.gold.withValues(alpha: 0.15),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '"Indeed, Allah does not change the condition of a people until they change what is within themselves."',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBBC8D8),
                          height: 1.65,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '— Qur\'an 13:11',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'The first step toward change is awareness. You\'ve already taken it.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'Build My Plan',
            icon: Icons.auto_awesome_rounded,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

// ─── Page 11: Location Permission ─────────────────────────────────────────────

class _LocationPage extends StatelessWidget {
  const _LocationPage({
    required this.granted,
    required this.requesting,
    required this.onRequestLocation,
    required this.onSkip,
    required this.onNext,
  });

  final bool granted;
  final bool requesting;
  final VoidCallback onRequestLocation;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                const _GlowIcon(
                  icon: Icons.location_on_rounded,
                  color: AppTheme.teal,
                  size: 80,
                  iconSize: 38,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Accurate Prayer Times\nRequire Your Location',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EDF4),
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prayer times vary by even a few kilometers. We use your GPS to calculate the exact times for your location.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _buildTrustCard(
                  icon: Icons.shield_rounded,
                  color: AppTheme.emerald,
                  title: 'Your privacy is protected',
                  subtitle: 'Location data never leaves your device. No servers, no tracking.',
                ),
                const SizedBox(height: 12),
                _buildTrustCard(
                  icon: Icons.offline_bolt_rounded,
                  color: AppTheme.teal,
                  title: 'Works offline',
                  subtitle: 'Once calculated, prayer times are cached locally for 30 days.',
                ),
                const SizedBox(height: 12),
                _buildTrustCard(
                  icon: Icons.edit_location_alt_rounded,
                  color: AppTheme.gold,
                  title: 'Manual fallback',
                  subtitle: 'You can always set your city manually in Settings.',
                ),
                if (granted) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.emerald.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.emerald,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Location access granted! Prayer times will be accurate.',
                            style: TextStyle(
                              color: AppTheme.emerald,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: granted
              ? _PrimaryBtn(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onNext,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PrimaryBtn(
                      label: requesting
                          ? 'Requesting...'
                          : 'Enable Location Access',
                      icon: requesting ? null : Icons.location_on_rounded,
                      onPressed: requesting ? null : onRequestLocation,
                      color: AppTheme.teal,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onSkip,
                      child: const Text(
                        'Continue without location',
                        style: TextStyle(
                          color: Color(0xFF8899AD),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTrustCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152032),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF253550)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE8EDF4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8899AD),
                    height: 1.4,
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

// ─── Page 12: Processing ──────────────────────────────────────────────────────

class _ProcessingPage extends StatelessWidget {
  const _ProcessingPage({required this.progress, required this.name});

  final double progress;
  final String name;

  static const _messages = [
    'Analyzing your prayer habits...',
    'Calculating your distraction patterns...',
    'Mapping your daily schedule...',
    'Designing your personalized plan...',
    'Finalizing your transformation roadmap...',
  ];

  String get _currentMessage {
    final idx = (progress * (_messages.length - 1)).round().clamp(0, _messages.length - 1);
    return _messages[idx];
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFF1E2D44),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8EDF4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Building your plan, $name...',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE8EDF4),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                key: ValueKey<String>(_currentMessage),
                _currentMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8899AD),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 13: Plan Ready ──────────────────────────────────────────────────────

class _PlanReadyPage extends StatelessWidget {
  const _PlanReadyPage({required this.name, required this.onNext});
  final String name;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.emerald.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.emerald,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Your Personal Plan\nis Ready, $name!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8EDF4),
                      height: 1.2,
                      letterSpacing: -0.7,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Based on your answers, we\'ve designed a personalized path to help you pray consistently — starting today.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF8899AD),
                      height: 1.65,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _buildCheckItem('Customized prayer reminders'),
                  _buildCheckItem('Smart app-blocking schedule'),
                  _buildCheckItem('Curated Dua & Dhikr library'),
                  _buildCheckItem('Daily habit tracking'),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'See My Plan',
            icon: Icons.visibility_rounded,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppTheme.emerald,
              size: 15,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCDD5E0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 14: Results ─────────────────────────────────────────────────────────

class _ResultsPage extends StatelessWidget {
  const _ResultsPage({
    required this.name,
    required this.phoneHoursKey,
    required this.phoneHoursValue,
    required this.prayerCount,
    required this.onNext,
  });

  final String name;
  final String phoneHoursKey;
  final double phoneHoursValue;
  final int prayerCount;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final hoursReclaimed = (phoneHoursValue * 0.3 * 30).round();
    final missingPrayers = 5 - prayerCount.clamp(0, 5);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Here\'s Your\n30-Day Transformation',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8EDF4),
                    height: 1.2,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Based on what you shared, here\'s what changes when you stay committed:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8899AD),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                _ResultCard(
                  icon: Icons.phone_android_rounded,
                  color: const Color(0xFFEF4444),
                  title: 'Screen Time',
                  before: phoneHoursKey.isEmpty ? '4+ hours/day' : phoneHoursKey,
                  after: '${(phoneHoursValue * 0.7).toStringAsFixed(1)} hours/day',
                  bottomLabel: 'Reclaim ~$hoursReclaimed hrs/month',
                ),
                const SizedBox(height: 12),
                _ResultCard(
                  icon: Icons.mosque_rounded,
                  color: AppTheme.emerald,
                  title: 'Daily Prayers',
                  before: prayerCount < 0
                      ? 'Inconsistent'
                      : '$prayerCount prayer${prayerCount == 1 ? '' : 's'}/day',
                  after: '5 prayers/day',
                  bottomLabel: missingPrayers > 0
                      ? 'Add $missingPrayers more prayer${missingPrayers == 1 ? '' : 's'} — you can do it'
                      : 'Maintain your perfect streak!',
                ),
                const SizedBox(height: 12),
                const _ResultCard(
                  icon: Icons.self_improvement_rounded,
                  color: AppTheme.gold,
                  title: 'Mental Clarity',
                  before: 'Distracted & scattered',
                  after: 'Focused & purposeful',
                  bottomLabel: 'Salah 5× daily = natural mindfulness',
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152032),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF253550)),
                  ),
                  child: const Text(
                    '"Whoever does not give up false speech and evil actions, Allah is not in need of his leaving his food and drink." — Prophet Muhammad ﷺ\n\nLet\'s make sure every sacrifice leads to something real.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8899AD),
                      height: 1.65,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: "I'm Ready to Commit",
            icon: Icons.favorite_rounded,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.before,
    required this.after,
    required this.bottomLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String before;
  final String after;
  final String bottomLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF152032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF253550)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE8EDF4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A6D85),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      before,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8899AD),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF253550),
                size: 18,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '30 DAYS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.emerald,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      after,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bottomLabel,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 15: Features ────────────────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You Have Everything\nYou Need',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8EDF4),
                    height: 1.2,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Prayer Lock gives you tools that actively defend your worship time.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8899AD),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const _FeatureRow(
                  icon: Icons.phonelink_erase_rounded,
                  color: Color(0xFFEF4444),
                  title: 'App Blocker',
                  subtitle: 'Automatically blocks distracting apps during every prayer window.',
                ),
                const _FeatureRow(
                  icon: Icons.notifications_active_rounded,
                  color: AppTheme.teal,
                  title: 'Smart Adhan Alerts',
                  subtitle: 'Beautiful adhan + pre-prayer reminders so you\'re never caught off-guard.',
                ),
                const _FeatureRow(
                  icon: Icons.volunteer_activism_rounded,
                  color: AppTheme.gold,
                  title: 'Full Dua & Dhikr Library',
                  subtitle: '11+ categories of authentic duas for every moment of your day.',
                ),
                const _FeatureRow(
                  icon: Icons.auto_stories_rounded,
                  color: AppTheme.emerald,
                  title: 'Quran Reader',
                  subtitle: 'Full text, audio recitation, bookmarks and full-text search — always free.',
                ),
                const _FeatureRow(
                  icon: Icons.widgets_rounded,
                  color: Color(0xFF8B5CF6),
                  title: 'Home Screen Widget',
                  subtitle: 'Next prayer time + countdown right on your home screen.',
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.emerald.withValues(alpha: 0.10),
                        AppTheme.teal.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.emerald.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '🕌',
                        style: TextStyle(fontSize: 28),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Join thousands of Muslims who are building better habits and strengthening their connection with Allah.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFBBC8D8),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: _PrimaryBtn(
            label: 'Begin My Transformation',
            icon: Icons.rocket_launch_rounded,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8EDF4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8899AD),
                    height: 1.45,
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

// ─── Page 16: App Blocker Permission ─────────────────────────────────────────

class _AppBlockerPage extends StatelessWidget {
  const _AppBlockerPage({required this.onNext, required this.onSkip});
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                const _GlowIcon(
                  icon: Icons.phonelink_erase_rounded,
                  color: Color(0xFFEF4444),
                  size: 80,
                  iconSize: 38,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Enable App Blocking\nfor Maximum Focus',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8EDF4),
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Prayer Lock\'s App Blocker automatically prevents access to distracting apps during every prayer window.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8899AD),
                    height: 1.65,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                _buildStep(
                  '1',
                  'Select apps to block',
                  'Choose Instagram, YouTube, TikTok — any app that pulls you away.',
                ),
                const SizedBox(height: 12),
                _buildStep(
                  '2',
                  'Prayer window activates',
                  'When Fajr (or any prayer) begins, the blocker activates automatically.',
                ),
                const SizedBox(height: 12),
                _buildStep(
                  '3',
                  'Pray, then unblock',
                  'Confirm "I have prayed" to unblock. No fake-outs — Allah is watching.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152032),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF253550)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.android_rounded,
                        color: Color(0xFF8899AD),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'App Blocker is Android-only. Requires Usage Access permission in Settings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8899AD),
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
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PrimaryBtn(
                label: 'Enable App Blocker',
                icon: Icons.phonelink_erase_rounded,
                onPressed: onNext,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip for now — set up later in Settings',
                  style: TextStyle(
                    color: Color(0xFF8899AD),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152032),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF253550)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8EDF4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8899AD),
                    height: 1.4,
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

// ─── Page 17: Paywall (Mandatory) ─────────────────────────────────────────────

class _PaywallPage extends StatelessWidget {
  const _PaywallPage({
    required this.selectedPlan,
    required this.onPlanSelect,
    required this.isLoading,
    required this.errorMessage,
    required this.onPurchase,
    required this.onRestore,
    this.onDebugSkip,
  });

  final _Plan selectedPlan;
  final ValueChanged<_Plan> onPlanSelect;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onPurchase;
  final Future<void> Function() onRestore;
  final Future<void> Function()? onDebugSkip;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final cs = Theme.of(context).colorScheme;
    final gold = AppTheme.gold;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                // Gold premium icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        gold.withValues(alpha: 0.25),
                        gold.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: gold.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: gold,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Prayer Lock',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8EDF4),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3,),
                      decoration: BoxDecoration(
                        color: gold,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A00),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Complete your transformation. Unlock every tool.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8899AD),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Features
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152032),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF253550)),
                  ),
                  child: Column(
                    children: [
                      _PaywallFeatureRow(
                        icon: Icons.phonelink_erase_rounded,
                        color: const Color(0xFFEF4444),
                        title: 'App Blocker',
                        subtitle: 'Block distractions during every Salah',
                        cs: cs,
                      ),
                      _PaywallDivider(),
                      _PaywallFeatureRow(
                        icon: Icons.volunteer_activism_rounded,
                        color: AppTheme.teal,
                        title: 'Full Dua & Hadith',
                        subtitle: '11+ categories · all 10 hadith collections',
                        cs: cs,
                      ),
                      _PaywallDivider(),
                      _PaywallFeatureRow(
                        icon: Icons.widgets_rounded,
                        color: cs.primary,
                        title: 'Home Screen Widget',
                        subtitle: 'Next prayer + countdown on your home screen',
                        cs: cs,
                      ),
                      _PaywallDivider(),
                      _PaywallFeatureRow(
                        icon: Icons.do_not_disturb_on_total_silence_rounded,
                        color: gold,
                        title: 'Ad-Free Forever',
                        subtitle: 'No interruptions during your worship',
                        cs: cs,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Plan selector
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose your plan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8899AD),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _PlanCard(
                        plan: _Plan.monthly,
                        selected: selectedPlan == _Plan.monthly,
                        gold: gold,
                        onTap: () => onPlanSelect(_Plan.monthly),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PlanCard(
                        plan: _Plan.lifetime,
                        selected: selectedPlan == _Plan.lifetime,
                        gold: gold,
                        onTap: () => onPlanSelect(_Plan.lifetime),
                      ),
                    ),
                  ],
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFEF4444),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom CTA
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    disabledBackgroundColor: gold.withValues(alpha: 0.4),
                    foregroundColor: const Color(0xFF1A1A00),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF1A1A00),
                          ),
                        )
                      : Text(
                          selectedPlan == _Plan.lifetime
                              ? 'Unlock Pro — \$39.99 Once'
                              : 'Start Pro — \$2.99/month',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selectedPlan == _Plan.lifetime
                    ? 'One-time payment · No subscription · Billed via App Store / Google Play'
                    : 'Cancel anytime · Billed monthly via App Store / Google Play',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF5A6D85),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FooterLink(
                    label: 'Restore Purchases',
                    onTap: isLoading ? null : () => onRestore(),
                  ),
                  const _Sep(),
                  _FooterLink(label: 'Privacy Policy', onTap: () {}),
                  const _Sep(),
                  _FooterLink(label: 'Terms', onTap: () {}),
                ],
              ),
              if (onDebugSkip != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => onDebugSkip!(),
                  child: const Text(
                    '[DEBUG] Skip paywall',
                    style: TextStyle(
                      color: Color(0xFF5A6D85),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PaywallFeatureRow extends StatelessWidget {
  const _PaywallFeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.cs,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE8EDF4),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8899AD),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.emerald,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _PaywallDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 48,
      color: const Color(0xFF253550).withValues(alpha: 0.6),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.gold,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final Color gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLifetime = plan == _Plan.lifetime;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            decoration: BoxDecoration(
              color: selected
                  ? gold.withValues(alpha: 0.10)
                  : const Color(0xFF152032),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? gold : const Color(0xFF253550),
                width: selected ? 1.75 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLifetime ? 'Lifetime' : 'Monthly',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? gold : const Color(0xFF8899AD),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLifetime ? r'$39.99' : r'$2.99',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: selected ? gold : const Color(0xFFE8EDF4),
                    height: 1.1,
                  ),
                ),
                Text(
                  isLifetime ? 'one-time' : 'per month',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8899AD),
                  ),
                ),
                if (isLifetime) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'No monthly fee',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.emerald,
                    ),
                  ),
                ] else
                  const SizedBox(height: 17),
              ],
            ),
          ),
          if (isLifetime)
            Positioned(
              top: -10,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.emerald,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: gold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: Color(0xFF1A1A00),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF8899AD),
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF253550),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(color: Color(0xFF253550), fontSize: 13),
      ),
    );
  }
}
