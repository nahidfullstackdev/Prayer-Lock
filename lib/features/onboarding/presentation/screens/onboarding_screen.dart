import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:prayer_lock/core/theme/app_theme.dart';
import 'package:prayer_lock/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:prayer_lock/main_screen.dart';

// ─── Main Onboarding Screen ──────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _locationGranted = false;
  bool _notifGranted = false;
  bool _requestingPermissions = false;

  late final AnimationController _entryAnim;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryFade = CurvedAnimation(
      parent: _entryAnim,
      curve: Curves.easeOut,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut));
    _entryAnim.forward();
    _checkExistingPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPermissions() async {
    final locStatus = await Permission.location.status;
    final notifStatus = await Permission.notification.status;
    if (!mounted) return;
    setState(() {
      _locationGranted = locStatus.isGranted;
      _notifGranted = notifStatus.isGranted || notifStatus.isLimited;
    });
  }

  void _goNext() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingNotifierProvider).complete();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: const MainScreen(),
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    if (_requestingPermissions) return;
    setState(() => _requestingPermissions = true);
    try {
      final locStatus = await Permission.location.request();
      final notifStatus = await Permission.notification.request();
      if (!mounted) return;
      setState(() {
        _locationGranted = locStatus.isGranted;
        _notifGranted = notifStatus.isGranted || notifStatus.isLimited;
      });
    } finally {
      if (mounted) setState(() => _requestingPermissions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1520),
      body: Stack(
        children: [
          // Subtle Islamic geometric background
          Positioned.fill(
            child: CustomPaint(
              painter: _IslamicPatternPainter(),
            ),
          ),

          // Main content
          FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: Column(
                children: [
                  // ── Skip button ─────────────────────────────────────────
                  SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 52,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedOpacity(
                          opacity: _currentPage < 3 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: _currentPage < 3 ? _finish : null,
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                color: Color(0xFF8899AD),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Page view ───────────────────────────────────────────
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      children: [
                        const _WelcomePage(),
                        _PrayerTimesPage(
                          locationGranted: _locationGranted,
                          notifGranted: _notifGranted,
                        ),
                        const _FeaturesPage(),
                        const _ProPage(),
                      ],
                    ),
                  ),

                  // ── Bottom controls ─────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            4,
                            (i) => _PageDot(active: i == _currentPage),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Buttons
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildBottomButtons(),
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

  Widget _buildBottomButtons() {
    if (_currentPage == 1) {
      if (_locationGranted && _notifGranted) {
        return _PrimaryButton(
          key: const ValueKey('permissions-granted'),
          onPressed: _goNext,
          label: 'Continue',
        );
      }
      return Column(
        key: const ValueKey('permissions-pending'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrimaryButton(
            onPressed: _requestingPermissions ? null : _requestPermissions,
            label: _requestingPermissions ? 'Requesting…' : 'Enable Permissions',
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _goNext,
            child: const Text(
              'Skip for now',
              style: TextStyle(
                color: Color(0xFF8899AD),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      key: ValueKey<int>(_currentPage),
      mainAxisSize: MainAxisSize.min,
      children: [
        _PrimaryButton(
          onPressed: _goNext,
          label: _currentPage == 3 ? 'Start for Free' : 'Continue',
          icon: _currentPage == 3 ? Icons.rocket_launch_rounded : null,
        ),
        if (_currentPage == 3) ...[
          const SizedBox(height: 10),
          const Text(
            'Upgrade to Pro anytime in Settings',
            style: TextStyle(
              color: Color(0xFF5A6D85),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ─── Shared Components ───────────────────────────────────────────────────────

class _PageDot extends StatelessWidget {
  const _PageDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 26 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppTheme.emerald : const Color(0xFF1E2D44),
        borderRadius: BorderRadius.circular(4),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppTheme.emerald.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          disabledBackgroundColor: AppTheme.emerald.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
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

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 14,
              color: AppTheme.emerald,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFCDD5E0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: granted
            ? color.withValues(alpha: 0.07)
            : const Color(0xFF152032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted ? color.withValues(alpha: 0.45) : const Color(0xFF253550),
          width: 1.5,
        ),
      ),
      child: Row(
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
                    color: Color(0xFFE8EDF4),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8899AD),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: granted
                ? Container(
                    key: const ValueKey('granted'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          'Granted',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('pending'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2840),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        color: Color(0xFF8899AD),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 1: Welcome ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const _MosqueIllustration(),
          const SizedBox(height: 24),
          // Bismillah
          const Text(
            'بِسْمِ ٱللَّٰهِ الرَّحْمَٰنِ الرَّحِيمِ',
            style: TextStyle(
              fontSize: 22,
              color: AppTheme.gold,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 22),
          // App name
          const Text(
            'Prayer Lock',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8EDF4),
              letterSpacing: -2.0,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Tagline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.emerald,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          // Description
          const Text(
            'The discipline system for modern Muslims who struggle with focus in a digital world. Reliable prayer times, beautiful adhan, and tools to protect your worship.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8899AD),
              height: 1.65,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Mosque Illustration ──────────────────────────────────────────────────────

class _MosqueIllustration extends StatelessWidget {
  const _MosqueIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outermost soft glow
          Container(
            width: 210,
            height: 210,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.emerald.withValues(alpha: 0.09),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Outer ring
          Container(
            width: 158,
            height: 158,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.emerald.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
          ),
          // Inner filled circle
          Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.emerald.withValues(alpha: 0.07),
              border: Border.all(
                color: AppTheme.emerald.withValues(alpha: 0.22),
                width: 1.5,
              ),
            ),
          ),
          // Mosque icon
          const Icon(
            Icons.mosque_rounded,
            size: 68,
            color: AppTheme.emerald,
          ),
          // Crescent moon top-right
          Positioned(
            top: 22,
            right: 46,
            child: CustomPaint(
              size: const Size(28, 28),
              painter: _CrescentPainter(),
            ),
          ),
          // Gold stars
          Positioned(
            top: 32,
            left: 56,
            child: Icon(
              Icons.star_rounded,
              size: 11,
              color: AppTheme.gold.withValues(alpha: 0.75),
            ),
          ),
          Positioned(
            top: 52,
            right: 34,
            child: Icon(
              Icons.star_rounded,
              size: 7,
              color: AppTheme.gold.withValues(alpha: 0.5),
            ),
          ),
          Positioned(
            bottom: 44,
            right: 50,
            child: Icon(
              Icons.star_rounded,
              size: 9,
              color: AppTheme.gold.withValues(alpha: 0.55),
            ),
          ),
          Positioned(
            bottom: 42,
            left: 40,
            child: Icon(
              Icons.star_rounded,
              size: 6,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
          ),
          Positioned(
            top: 70,
            left: 30,
            child: Icon(
              Icons.star_rounded,
              size: 8,
              color: AppTheme.gold.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Crescent Moon Painter ────────────────────────────────────────────────────

class _CrescentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = AppTheme.gold
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx + r * 0.40, cy - r * 0.08),
      r * 0.82,
      Paint()
        ..color = Colors.black
        ..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Page 2: Prayer Times + Permissions ──────────────────────────────────────

class _PrayerTimesPage extends StatelessWidget {
  const _PrayerTimesPage({
    required this.locationGranted,
    required this.notifGranted,
  });
  final bool locationGranted;
  final bool notifGranted;

  static const List<String> _bullets = [
    'GPS-based prayer times, updated daily',
    'Beautiful adhan & special Fajr call',
    'Pre-prayer reminders, fully customisable',
    '20+ calculation methods worldwide',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Center(child: _PrayerIllustration()),
          const SizedBox(height: 26),
          const Text(
            'Never Miss\na Prayer',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8EDF4),
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Accurate prayer times and a beautiful adhan wherever you are.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8899AD),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          ..._bullets.map((b) => _FeatureBullet(text: b)),
          const SizedBox(height: 24),
          const Text(
            'REQUIRED PERMISSIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF5A6D85),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _PermissionCard(
            icon: Icons.location_on_rounded,
            title: 'Location Access',
            subtitle: 'For accurate prayer times in your city',
            granted: locationGranted,
            color: AppTheme.teal,
          ),
          const SizedBox(height: 10),
          _PermissionCard(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'To play adhan when it\'s prayer time',
            granted: notifGranted,
            color: AppTheme.gold,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Prayer Times Illustration ────────────────────────────────────────────────

class _PrayerIllustration extends StatelessWidget {
  const _PrayerIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.teal.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF152032),
              border: Border.all(
                color: AppTheme.teal.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              size: 38,
              color: AppTheme.teal,
            ),
          ),
          const Positioned(
            top: 10,
            right: 28,
            child: _PrayerPill(name: 'Fajr', time: '05:24'),
          ),
          const Positioned(
            bottom: 10,
            left: 18,
            child: _PrayerPill(name: 'Dhuhr', time: '12:30'),
          ),
          const Positioned(
            top: 55,
            right: 8,
            child: _PrayerPill(name: 'Asr', time: '15:48'),
          ),
        ],
      ),
    );
  }
}

class _PrayerPill extends StatelessWidget {
  const _PrayerPill({required this.name, required this.time});
  final String name;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2840),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.emerald.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF8899AD),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: const TextStyle(
              color: AppTheme.emerald,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 3: Daily Features ───────────────────────────────────────────────────

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Your Daily\nWorship Companion',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8EDF4),
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Everything you need for daily worship, beautifully crafted for the modern Muslim.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8899AD),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: const [
              _FeatureCard(
                icon: Icons.menu_book_rounded,
                color: AppTheme.emerald,
                title: 'Full Quran',
                subtitle: '114 surahs with\naudio recitation',
                badgeText: 'FREE',
                badgeColor: AppTheme.emerald,
              ),
              _FeatureCard(
                icon: Icons.volunteer_activism_rounded,
                color: AppTheme.gold,
                title: 'Dua & Dhikr',
                subtitle: 'Morning, evening\n& travel duas',
                badgeText: 'FREE',
                badgeColor: AppTheme.emerald,
              ),
              _FeatureCard(
                icon: Icons.format_list_bulleted_rounded,
                color: Color(0xFF8B5CF6),
                title: 'Hadith',
                subtitle: 'Daily hadith with\nexplanations',
                badgeText: 'FREE',
                badgeColor: AppTheme.emerald,
              ),
              _FeatureCard(
                icon: Icons.explore_rounded,
                color: AppTheme.teal,
                title: 'Qibla',
                subtitle: 'Accurate compass\nanywhere',
                badgeText: 'FREE',
                badgeColor: AppTheme.emerald,
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2D44)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.07),
            const Color(0xFF152032),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFE8EDF4),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF8899AD),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 4: Pro Features ─────────────────────────────────────────────────────

class _ProPage extends StatelessWidget {
  const _ProPage();

  static const List<(IconData, String, Color)> _proFeatures = [
    (
      Icons.lock_outline_rounded,
      'Block Instagram & TikTok during prayer',
      AppTheme.emerald,
    ),
    (
      Icons.menu_book_rounded,
      'Full Dua & Hadith collection',
      AppTheme.teal,
    ),
    (
      Icons.widgets_rounded,
      'Home screen prayer widget',
      AppTheme.gold,
    ),
    (
      Icons.hide_image_outlined,
      'Completely ad-free experience',
      Color(0xFF8B5CF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _AppBlockerIllustration(),
          const SizedBox(height: 20),
          // Pro badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.gold, AppTheme.goldLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  size: 15,
                  color: Color(0xFF3D2200),
                ),
                SizedBox(width: 6),
                Text(
                  'Prayer Lock Pro',
                  style: TextStyle(
                    color: Color(0xFF3D2200),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Lock Out\nDistractions',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE8EDF4),
              letterSpacing: -1.5,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Block distracting apps during prayer windows. Stay disciplined, stay accountable.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF8899AD),
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Pro feature rows
          ..._proFeatures.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: f.$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(f.$1, color: f.$3, size: 19),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      f.$2,
                      style: const TextStyle(
                        color: Color(0xFFCDD5E0),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Accountability quote
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF152032),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🤲', style: TextStyle(fontSize: 22)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"I have prayed — don\'t fake it,\nAllah is watching you."',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── App Blocker Illustration ─────────────────────────────────────────────────

class _AppBlockerIllustration extends StatelessWidget {
  const _AppBlockerIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Gold glow
          Container(
            width: 155,
            height: 155,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.gold.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Lock circle
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A2840),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.lock_rounded,
              size: 46,
              color: AppTheme.gold,
            ),
          ),
          // Blocked app indicators
          const Positioned(
            top: 14,
            left: 38,
            child: _BlockedApp(color: Color(0xFFE11D48)),
          ),
          const Positioned(
            top: 14,
            right: 38,
            child: _BlockedApp(color: Color(0xFF3B82F6)),
          ),
          const Positioned(
            bottom: 8,
            left: 56,
            child: _BlockedApp(color: Color(0xFFF59E0B)),
          ),
        ],
      ),
    );
  }
}

class _BlockedApp extends StatelessWidget {
  const _BlockedApp({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(
            Icons.apps_rounded,
            size: 18,
            color: color.withValues(alpha: 0.5),
          ),
        ),
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            width: 17,
            height: 17,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Islamic Pattern Background ───────────────────────────────────────────────

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.028)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const spacing = 72.0;
    final cols = (size.width / spacing).ceil() + 2;
    final rows = (size.height / spacing).ceil() + 2;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = c * spacing + (r.isOdd ? spacing / 2 : 0.0);
        final cy = r * spacing * 0.866;
        _drawEightPointStar(canvas, paint, Offset(cx, cy), 16);
      }
    }
  }

  void _drawEightPointStar(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
  ) {
    const points = 8;
    final innerRadius = radius * 0.42;
    final path = Path();

    for (var i = 0; i < points * 2; i++) {
      final angle = (i * math.pi / points) - math.pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
