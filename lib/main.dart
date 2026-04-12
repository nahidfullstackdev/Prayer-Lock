import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:prayer_lock/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/notification_service.dart';
import 'package:prayer_lock/features/subscription/data/services/revenuecat_service.dart';
import 'package:prayer_lock/firebase_options.dart';
import 'package:prayer_lock/main_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prayer_lock/core/theme/app_theme.dart';
import 'package:prayer_lock/core/theme/theme_provider.dart';

import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialised first — auth & Firestore depend on it.
  // Replace firebase_options.dart by running: flutterfire configure
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics: capture all Flutter framework errors (widget build failures,
    // layout overflows, assertion errors, etc.)
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Crashlytics: capture uncaught async errors that escape the root zone
    // (e.g. unhandled Future rejections, isolate errors)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Disable data collection in debug builds to keep the dashboard clean
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  } catch (e) {
    AppLogger.error(
      'Firebase initialization failed — auth/crash reporting disabled',
      e,
    );
  }

  // Alarm manager must be initialised before runApp so that alarms scheduled
  // during the session (and on reboot) can fire correctly.
  await AndroidAlarmManager.initialize();

  await Hive.initFlutter();
  await Hive.openBox<dynamic>('quran_data');
  await Hive.openBox<dynamic>('app_blocker');

  // Initialize prayer times Hive boxes and adapters
  final prayerTimesLocalDataSource = PrayerTimesLocalDataSource();
  await prayerTimesLocalDataSource.initialize();

  // Initialise notification service: creates channels only.
  // Permission is requested later — after onboarding + Pro upgrade — via HomeScreen.
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Configure RevenueCat SDK.  The singleton listens for CustomerInfo updates
  // and broadcasts status changes via subscriptionStatusProvider.
  await RevenueCatService.configure();

  runApp(const ProviderScope(child: MuslimCompanionApp()));
}

/// Bottom navigation tab index — shared so child screens can switch tabs
final selectedTabProvider = StateProvider<int>((ref) => 0);

class MuslimCompanionApp extends ConsumerWidget {
  const MuslimCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Sync system UI with theme
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

/// Checks onboarding completion on first launch and routes accordingly.
class _AppHome extends ConsumerWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingCompletedProvider);
    return onboardingAsync.when(
      data: (completed) => completed ? const MainScreen() : const MainScreen(),
      loading: () => const _SplashScreen(),
      error: (_, __) => const MainScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1520),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald),
          strokeWidth: 2,
        ),
      ),
    );
  }
}
