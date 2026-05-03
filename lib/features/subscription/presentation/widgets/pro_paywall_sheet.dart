// ─── Pro Paywall Sheet ───────────────────────────────────────────────────────
//
// Custom paywall for Prayer Lock Pro. Shown as a modal bottom sheet wherever
// the user taps a Pro-locked CTA.
//
// Auth gate: if the user is not signed in, [AuthSheet] is shown first.
// After a successful sign-in the purchase flow resumes automatically.
//
// Usage:
//   showProPaywall(
//     context,
//     ref.read(subscriptionRepositoryProvider),
//     placement: 'dua_locked',
//     featureTitle: 'Dua Categories',
//   );

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/auth/presentation/providers/auth_providers.dart';
import 'package:prayer_lock/features/auth/presentation/screens/auth_screen.dart';
import 'package:prayer_lock/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:url_launcher/url_launcher.dart';
// ─── Public helper ────────────────────────────────────────────────────────────

/// Presents the [ProPaywallSheet] as a modal bottom sheet.
///
/// [repo]               — subscription repository (purchase / restore).
/// [placement]          — analytics ID forwarded to RevenueCat.
/// [featureTitle]       — name of the locked feature (shows in subtitle).
/// [featureDescription] — extra context copy shown below the subtitle.
Future<void> showProPaywall(
  BuildContext context,
  SubscriptionRepository repo, {
  String placement = 'generic',
  String? featureTitle,
  String? featureDescription,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (_) => ProPaywallSheet(
          featureTitle: featureTitle,
          featureDescription: featureDescription,
          onUpgradeTap: (planId) => repo.purchase(planId),
          onRestoreTap: repo.restorePurchases,
        ),
  );
}

// ─── Widget ───────────────────────────────────────────────────────────────────

/// Custom-designed paywall. Separated into its own widget so it can be shown
/// from any context without duplicating UI code.
///
/// This is a [ConsumerStatefulWidget] so it can read [isSignedInProvider] and
/// [authRepositoryProvider] to gate the purchase flow behind authentication.
class ProPaywallSheet extends ConsumerStatefulWidget {
  const ProPaywallSheet({
    super.key,
    this.featureTitle,
    this.featureDescription,
    required this.onUpgradeTap,
    required this.onRestoreTap,
    this.embedded = false,
    this.onPurchaseSuccess,
    this.onRestoreSuccess,
    this.onSkip,
    this.onDebugSkip,
  });

  /// e.g. `'App Blocker'` → header reads "Unlock App Blocker and more"
  final String? featureTitle;

  /// Extra copy shown below the header subtitle.
  final String? featureDescription;

  /// Called when the user taps the primary CTA (after auth gate passes).
  /// Receives `'weekly'` or `'annual'` based on the selected plan card.
  ///
  /// Resolves to `true` when the `pro` entitlement is active afterwards
  /// (purchase completed) and `false` when the user cancelled the store
  /// dialog. Throws on billing / configuration errors so the sheet can
  /// surface a snackbar. When [embedded] is false the sheet closes only on
  /// `true`.
  final Future<bool> Function(String planId) onUpgradeTap;

  /// Called when the user taps "Restore Purchases".
  final Future<void> Function() onRestoreTap;

  /// When true, the widget renders without the bottom-sheet handle and does
  /// not pop the navigation route after a purchase / restore. Use this when
  /// embedding the paywall as a full page (e.g. onboarding) instead of a
  /// modal sheet.
  final bool embedded;

  /// Invoked after [onUpgradeTap] resolves, only when [embedded] is true.
  /// Caller decides what to do (e.g. check entitlement and navigate forward).
  final VoidCallback? onPurchaseSuccess;

  /// Invoked after [onRestoreTap] resolves, only when [embedded] is true.
  final VoidCallback? onRestoreSuccess;

  /// Optional user-facing "Skip for now" button shown below the footer in
  /// embedded mode (e.g. onboarding). When null, nothing is rendered — the
  /// paywall stays mandatory. Separate from [onDebugSkip] so the two can
  /// coexist without conflicting copy.
  final VoidCallback? onSkip;

  /// Optional debug-only escape hatch shown below the footer in embedded mode.
  final VoidCallback? onDebugSkip;

  @override
  ConsumerState<ProPaywallSheet> createState() => _ProPaywallSheetState();
}

// ─── State ────────────────────────────────────────────────────────────────────

enum _Plan { weekly, yearly }

class _ProPaywallSheetState extends ConsumerState<ProPaywallSheet> {
  _Plan _selectedPlan = _Plan.yearly;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F1E2D) : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius:
            widget.embedded
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!widget.embedded) _buildTopBar(cs),
              if (widget.embedded) const SizedBox(height: 8),
              _buildHeader(cs, isDark),
              const SizedBox(height: 24),
              _buildFeatures(cs, isDark),
              const SizedBox(height: 24),
              _buildPricingSection(cs, isDark),
              const SizedBox(height: 20),
              _buildCTA(cs, isDark),
              const SizedBox(height: 14),
              _buildFooter(cs),
              if (widget.embedded && widget.onSkip != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    'Skip for now',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: cs.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.embedded && widget.onDebugSkip != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: widget.onDebugSkip,
                  child: Text(
                    '[DEBUG] Skip paywall',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar (handle + close) ────────────────────────────────────────────────

  Widget _buildTopBar(ColorScheme cs) {
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
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
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.close_rounded,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
              tooltip: 'Close',
              splashRadius: 20,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, bool isDark) {
    final gold = cs.secondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          // Glowing premium icon
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  gold.withValues(alpha: 0.28),
                  gold.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: gold.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: gold, size: 42),
          ),
          const SizedBox(height: 18),

          // "Prayer Lock PRO" title + badge
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Prayer Lock',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: gold,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF1A1A00) : Colors.white,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Context-specific or generic subtitle
          Text(
            widget.featureTitle != null
                ? 'Unlock ${widget.featureTitle} and more'
                : 'Build discipline. Pray on time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),

          if (widget.featureDescription != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.featureDescription!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Features ─────────────────────────────────────────────────────────────────

  Widget _buildFeatures(ColorScheme cs, bool isDark) {
    final cardBg =
        isDark
            ? cs.surfaceContainer.withValues(alpha: 0.55)
            : cs.surfaceContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            _ProFeatureRow(
              icon: Icons.phonelink_erase_rounded,
              color: const Color(0xFFEF4444),
              title: 'App Blocker',
              subtitle: 'Block distracting apps during every Salah window',
              cs: cs,
            ),
            _buildDivider(cs),
            _ProFeatureRow(
              icon: Icons.volunteer_activism_rounded,
              color: cs.tertiary,
              title: 'Full Dua & Hadith',
              subtitle: '11+ dua categories · all 10 hadith collections',
              cs: cs,
            ),
            _buildDivider(cs),
            _ProFeatureRow(
              icon: Icons.widgets_rounded,
              color: cs.primary,
              title: 'Home Screen Widget',
              subtitle: 'Next prayer + live countdown on your home screen',
              cs: cs,
            ),
            _buildDivider(cs),
            _ProFeatureRow(
              icon: Icons.do_not_disturb_on_total_silence_rounded,
              color: cs.secondary,
              title: 'Ad-Free Forever',
              subtitle: 'No banners, no interruptions — just worship',
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme cs) {
    return Divider(
      height: 1,
      indent: 52,
      color: cs.outlineVariant.withValues(alpha: 0.5),
    );
  }

  // ── Pricing ──────────────────────────────────────────────────────────────────

  Widget _buildPricingSection(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 12),
            child: Text(
              'Choose your plan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _PlanCard(
                  plan: _Plan.weekly,
                  selected: _selectedPlan == _Plan.weekly,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedPlan = _Plan.weekly),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PlanCard(
                  plan: _Plan.yearly,
                  selected: _selectedPlan == _Plan.yearly,
                  cs: cs,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedPlan = _Plan.yearly),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── CTA ──────────────────────────────────────────────────────────────────────

  Widget _buildCTA(ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleUpgrade,
              style: FilledButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor:
                    isDark ? const Color(0xFF1A1A00) : Colors.white,
                disabledBackgroundColor: cs.secondary.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child:
                  _isLoading
                      ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color:
                              isDark ? const Color(0xFF1A1A00) : Colors.white,
                        ),
                      )
                      : const Text(
                        'Unlock Pro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
            ),
          ),
          const SizedBox(height: 8),
          // TODO: replace static prices with RevenueCat product priceStrings
          //       via Purchases.getOfferings() when products are configured.
          Text(
            _billingNote(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FooterLink(
          label: 'Restore Purchases',
          cs: cs,
          onTap: _isLoading ? null : _handleRestore,
        ),
        _FooterSeparator(cs: cs),
        _FooterLink(
          label: 'Privacy Policy',
          cs: cs,
          onTap: _openPrivacyPolicy,
        ),
      ],
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://sites.google.com/view/prayer-lock/home');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Privacy Policy')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Privacy Policy')),
      );
    }
  }

  // ── Upgrade flow (auth-gated) ─────────────────────────────────────────────────

  Future<void> _handleUpgrade() async {
    // ── Step 1: ensure user is signed in ──────────────────────────────────────
    final isSignedIn = ref.read(isSignedInProvider);
    if (!isSignedIn) {
      final repo = ref.read(authRepositoryProvider);
      final signedIn = await showAuthSheet(context, repo);
      // User cancelled auth — stay on paywall.
      if (!signedIn || !mounted) return;
    }

    // ── Step 2: purchase ───────────────────────────────────────────────────────
    setState(() => _isLoading = true);
    try {
      final planId = _selectedPlan == _Plan.yearly ? 'annual' : 'weekly';
      final purchased = await widget.onUpgradeTap(planId);
      if (!mounted) return;

      // User cancelled the store dialog (or entitlement still not active) —
      // keep the paywall open silently so they can try again.
      if (!purchased) return;

      if (widget.embedded) {
        widget.onPurchaseSuccess?.call();
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyPurchaseError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyPurchaseError(Object e) {
    if (e is SubscriptionPurchaseException) return e.message;
    return 'Something went wrong with the purchase. Please try again.';
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    try {
      await widget.onRestoreTap();
      if (!mounted) return;
      if (widget.embedded) {
        widget.onRestoreSuccess?.call();
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      // Logged in service layer.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _billingNote() {
    // TODO: swap with RevenueCat product priceStrings when configured.
    final store = _isAndroid() ? 'Google Play' : 'App Store';
    if (_selectedPlan == _Plan.yearly) {
      return '3-day free trial, then \$14.99/year · Cancel anytime · Billed via $store';
    }
    return 'Billed at \$0.99/week · Cancel anytime · Billed via $store';
  }

  bool _isAndroid() {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return true;
    }
  }
}

// ─── Private widgets ──────────────────────────────────────────────────────────

class _ProFeatureRow extends StatelessWidget {
  const _ProFeatureRow({
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
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
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.check_circle_rounded, color: cs.primary, size: 18),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });

  final _Plan plan;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isYearly = plan == _Plan.yearly;
    final gold = cs.secondary;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: BoxDecoration(
              color:
                  selected
                      ? gold.withValues(alpha: isDark ? 0.12 : 0.08)
                      : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? gold : cs.outlineVariant,
                width: selected ? 1.75 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isYearly ? 'Yearly' : 'Weekly',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? gold : cs.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isYearly ? r'$14.99' : r'$0.99',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: selected ? gold : cs.onSurface,
                    height: 1.1,
                  ),
                ),
                Text(
                  isYearly ? 'per year' : 'per week',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Text(
                  isYearly
                      ? r'Only $1.25/m after free trial'
                      : r'Billed at $0.99',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isYearly ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // 3-DAY FREE TRIAL badge on yearly card
          if (isYearly)
            Positioned(
              top: -11,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '3-DAY FREE TRIAL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

          // Gold checkmark when selected
          if (selected)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(color: gold, shape: BoxShape.circle),
                child: Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: isDark ? const Color(0xFF1A1A00) : Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.cs,
    required this.onTap,
  });

  final String label;
  final ColorScheme cs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant,
          decoration: TextDecoration.underline,
          decorationColor: cs.outlineVariant,
        ),
      ),
    );
  }
}

class _FooterSeparator extends StatelessWidget {
  const _FooterSeparator({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(color: cs.outlineVariant, fontSize: 14),
      ),
    );
  }
}
