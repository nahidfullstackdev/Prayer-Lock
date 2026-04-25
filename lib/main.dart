import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/startup/app_initializer.dart';
import 'package:prayer_lock/core/theme/app_theme.dart';
import 'package:prayer_lock/core/theme/theme_provider.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/core/widgets/brand_logo.dart';
import 'package:prayer_lock/features/auth/presentation/providers/auth_providers.dart';
import 'package:prayer_lock/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:prayer_lock/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:prayer_lock/firebase_options.dart';
import 'package:prayer_lock/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is the only thing we await before runApp — Crashlytics has to
  // install its error hooks before the first frame so nothing crashes
  // uncaught. Everything else is handled by AppInitializer after splash.
  await _initFirebase();

  runApp(const ProviderScope(child: MuslimCompanionApp()));
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (e, st) {
    AppLogger.error(
      'Firebase initialization failed — auth/crash reporting disabled',
      e,
      st,
    );
  }
}

/// Bottom navigation tab index — shared so child screens can switch tabs
final selectedTabProvider = StateProvider<int>((ref) => 0);

class MuslimCompanionApp extends ConsumerWidget {
  const MuslimCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Activate the auth↔subscription bridge. It only listens to streams —
    // safe to wire up before RevenueCat has finished configuring in the
    // deferred phase; the first real CustomerInfo emission will push through.
    ref.read(subscriptionSyncServiceProvider);

    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF152032),
            systemNavigationBarIconBrightness: Brightness.light,
          )
          : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
    );

    return MaterialApp(
      title: 'Muslim Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _AppHome(),
    );
  }
}

// ─── App Router ──────────────────────────────────────────────────────────────

/// Drives the splash-phase boot sequence:
///   • initState kicks off the critical init (Hive / prayer datasource);
///   • when that completes, deferred work (alarms, TZ, notifications,
///     RevenueCat, home widget) is fired in the background without
///     blocking first interaction;
///   • splash is shown until the critical future resolves, then routing
///     continues based on onboarding state.
class _AppHome extends ConsumerStatefulWidget {
  const _AppHome();

  @override
  ConsumerState<_AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends ConsumerState<_AppHome> {
  late final Future<void> _critical;

  @override
  void initState() {
    super.initState();
    _critical = _bootstrap();
  }

  Future<void> _bootstrap() async {
    await AppInitializer.runCritical();
    // Deferred services run in the background — the UI is already
    // interactive by the time these complete.
    unawaited(AppInitializer.runDeferred());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _critical,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          AppLogger.error(
            'App critical init failed',
            snapshot.error,
            snapshot.stackTrace,
          );
          return const MainScreen();
        }
        final onboardingAsync = ref.watch(onboardingCompletedProvider);
        return onboardingAsync.when(
          data:
              (completed) =>
                  completed ? const MainScreen() : const OnboardingScreen(),
          loading: () => const _SplashScreen(),
          error: (_, __) => const MainScreen(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1520) : const Color(0xFFF5F2EB),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandLogo(size: 128),
            SizedBox(height: 32),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
