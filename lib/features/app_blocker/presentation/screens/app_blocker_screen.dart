import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/app_blocker/domain/entities/blocked_app.dart';
import 'package:prayer_lock/features/app_blocker/presentation/providers/app_blocker_providers.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_providers.dart';

class AppBlockerScreen extends ConsumerStatefulWidget {
  const AppBlockerScreen({super.key});

  @override
  ConsumerState<AppBlockerScreen> createState() => _AppBlockerScreenState();
}

class _AppBlockerScreenState extends ConsumerState<AppBlockerScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    // Load apps and check permissions after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appBlockerProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // User may have just returned from Android Settings — refresh permissions
      ref.read(appBlockerProvider.notifier).refreshPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('App Blocker')),
        body: const Center(
          child: Text('App Blocker is only available on Android.'),
        ),
      );
    }

    final state = ref.watch(appBlockerProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredApps =
        _searchQuery.isEmpty
            ? state.installedApps
            : state.installedApps
                .where(
                  (a) => a.appName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ),
                )
                .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'App Blocker',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors:
                        isDark
                            ? [const Color(0xFF0A2E1A), const Color(0xFF0D1520)]
                            : [
                              const Color(0xFF15803D),
                              const Color(0xFF166534),
                            ],
                  ),
                ),
              ),
            ),
          ),

          // ── Error banner ─────────────────────────────────────────────────
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                message: state.errorMessage!,
                onDismiss:
                    () =>
                        ref
                            .read(appBlockerProvider.notifier)
                            .refreshPermissions(),
              ),
            ),

          // ── Permission banners ───────────────────────────────────────────
          if (!state.hasAccessibilityPermission)
            SliverToBoxAdapter(
              child: _PermissionBanner(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility Service Required',
                subtitle:
                    'Detects which app is in the foreground during prayer windows. Prayer Lock never reads or transmits screen content.',
                buttonLabel: 'Grant Access',
                onTap:
                    () =>
                        ref
                            .read(appBlockerProvider.notifier)
                            .openAccessibilitySettings(),
              ),
            ),
          if (!state.hasOverlayPermission)
            SliverToBoxAdapter(
              child: _PermissionBanner(
                icon: Icons.layers_rounded,
                title: 'Display Over Other Apps',
                subtitle:
                    'Needed to show the prayer reminder on top of blocked apps.',
                buttonLabel: 'Grant Access',
                onTap:
                    () =>
                        ref
                            .read(appBlockerProvider.notifier)
                            .openOverlaySettings(),
              ),
            ),

          // ── Privacy disclosure (Play Store requirement) ──────────────────
          const SliverToBoxAdapter(child: _DisclosureCard()),

          // ── Auto-blocking toggle ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ServiceToggleCard(
              isAutoEnabled: state.isAutoBlockingEnabled,
              isToggling: state.isTogglingService,
              isEnabled: state.hasAllPermissions,
              blockedCount: state.blockedPackages.length,
              onToggle: (value) =>
                  ref.read(appBlockerProvider.notifier).toggleAutoBlocking(
                        enable: value,
                        prayerTimes:
                            ref.read(prayerTimesProvider).prayerTimes,
                      ),
            ),
          ),

          // ── Apps loading indicator ───────────────────────────────────────
          if (state.isLoadingApps)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading installed apps...',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // ── Section header ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Select Apps to Block',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const Spacer(),
                    if (state.blockedPackages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.blockedPackages.length} selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Search ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 14, color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: cs.onSurfaceVariant,
                      size: 20,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              onPressed: () => _searchController.clear(),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: cs.onSurfaceVariant,
                              ),
                            )
                            : null,
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

            // ── App list ───────────────────────────────────────────────────
            if (filteredApps.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? 'No apps found'
                        : 'No apps match "$_searchQuery"',
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList.builder(
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    final isBlocked = state.blockedPackages.contains(
                      app.packageName,
                    );
                    return _AppRow(
                      app: app,
                      isBlocked: isBlocked,
                      onTap:
                          () => ref
                              .read(appBlockerProvider.notifier)
                              .toggleApp(app.packageName),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Service Toggle Card ──────────────────────────────────────────────────────

class _ServiceToggleCard extends StatelessWidget {
  const _ServiceToggleCard({
    required this.isAutoEnabled,
    required this.isToggling,
    required this.isEnabled,
    required this.blockedCount,
    required this.onToggle,
  });

  final bool isAutoEnabled;
  final bool isToggling;
  final bool isEnabled;
  final int blockedCount;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isAutoEnabled
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAutoEnabled
                ? cs.primary.withValues(alpha: 0.3)
                : cs.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isAutoEnabled ? cs.primary : cs.onSurfaceVariant)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAutoEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: isAutoEnabled ? cs.primary : cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Block during prayer windows',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAutoEnabled
                        ? '$blockedCount app${blockedCount == 1 ? '' : 's'} blocked at adhan for 20 min'
                        : isEnabled
                            ? 'Activates automatically at each adhan'
                            : 'Grant permissions to enable',
                    style: TextStyle(
                      fontSize: 12,
                      color: isAutoEnabled ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isToggling)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              )
            else
              Switch.adaptive(
                value: isAutoEnabled,
                onChanged: isEnabled ? onToggle : null,
                activeThumbColor: cs.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Disclosure Card (Play Store transparency requirement) ────────────────────

class _DisclosureCard extends StatelessWidget {
  const _DisclosureCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              color: cs.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Prayer Lock uses Accessibility Service only to detect which app you\'re using and show a reminder during prayer windows. It never reads, records, or sends any screen content.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Permission Banner ────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFF59E0B), size: 22),
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
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
              ),
              child: Text(
                buttonLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error Banner ─────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: cs.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, size: 16, color: cs.error),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── App Row ──────────────────────────────────────────────────────────────────

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.app,
    required this.isBlocked,
    required this.onTap,
  });

  final BlockedApp app;
  final bool isBlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child:
                    app.iconBase64 != null
                        ? Image.memory(
                          base64Decode(app.iconBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _FallbackIcon(cs: cs),
                        )
                        : _FallbackIcon(cs: cs),
              ),
            ),
            const SizedBox(width: 14),
            // App name
            Expanded(
              child: Text(
                app.appName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isBlocked ? FontWeight.w600 : FontWeight.w400,
                  color: isBlocked ? cs.onSurface : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Checkbox
            Checkbox(
              value: isBlocked,
              onChanged: (_) => onTap(),
              activeColor: cs.primary,
              side: BorderSide(color: cs.outlineVariant, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.surfaceContainer,
      child: Icon(Icons.android_rounded, color: cs.onSurfaceVariant, size: 24),
    );
  }
}
