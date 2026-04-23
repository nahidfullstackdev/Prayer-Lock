import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_next_prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_prayer_times.dart';

/// State for Prayer Times
class PrayerTimesState {
  final PrayerTimes? prayerTimes;
  final Prayer? nextPrayer;
  final Duration? timeRemaining;
  final bool isLoading;
  final String? errorMessage;
  final bool isPermissionDenied;

  const PrayerTimesState({
    this.prayerTimes,
    this.nextPrayer,
    this.timeRemaining,
    this.isLoading = false,
    this.errorMessage,
    this.isPermissionDenied = false,
  });

  PrayerTimesState copyWith({
    PrayerTimes? prayerTimes,
    Prayer? nextPrayer,
    Duration? timeRemaining,
    bool? isLoading,
    String? errorMessage,
    bool? isPermissionDenied,
  }) {
    return PrayerTimesState(
      prayerTimes: prayerTimes ?? this.prayerTimes,
      nextPrayer: nextPrayer ?? this.nextPrayer,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
    );
  }
}

/// State notifier for prayer times
class PrayerTimesNotifier extends StateNotifier<PrayerTimesState> {
  final GetPrayerTimesUseCase getPrayerTimesUseCase;
  final GetNextPrayerUseCase getNextPrayerUseCase;
  final NotificationRepository notificationRepository;
  Timer? _countdownTimer;

  PrayerTimesNotifier({
    required this.getPrayerTimesUseCase,
    required this.getNextPrayerUseCase,
    required this.notificationRepository,
  }) : super(const PrayerTimesState()) {
    loadPrayerTimes();
  }

  /// Load prayer times for today.
  /// Pass [settings] to reschedule notifications after a successful load.
  Future<void> loadPrayerTimes({
    LocationData? location,
    PrayerSettings? settings,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Loading prayer times...');

    final result = await getPrayerTimesUseCase(location: location);

    result.fold(
      (failure) {
        AppLogger.error('Failed to load prayer times: ${failure.message}');
        final isPermission =
            failure.message.toLowerCase().contains('permission') ||
                failure.message.toLowerCase().contains('denied');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          isPermissionDenied: isPermission,
        );
      },
      (prayerTimes) {
        AppLogger.info('Prayer times loaded successfully');
        final nextPrayer = getNextPrayerUseCase(prayerTimes);
        state = state.copyWith(
          prayerTimes: prayerTimes,
          nextPrayer: nextPrayer,
          isLoading: false,
          errorMessage: null,
          isPermissionDenied: false,
        );
        _startCountdown();

        // Schedule notifications when settings are provided.
        if (settings != null) {
          _scheduleNotifications(prayerTimes, settings);
        }
      },
    );
  }

  /// Explicitly reschedule notifications for already-loaded prayer times.
  /// Call this from the settings screen whenever the user changes a preference.
  Future<void> scheduleNotifications(PrayerSettings settings) async {
    final prayerTimes = state.prayerTimes;
    if (prayerTimes == null) return;
    _scheduleNotifications(prayerTimes, settings);
  }

  /// Refresh prayer times (re-fetches and reschedules with provided settings).
  Future<void> refresh({PrayerSettings? settings}) async {
    await loadPrayerTimes(settings: settings);
  }

  // ── private ──────────────────────────────────────────────────────────────────

  void _scheduleNotifications(
    PrayerTimes prayerTimes,
    PrayerSettings settings,
  ) {
    notificationRepository
        .scheduleAllPrayers(
          prayerTimes: prayerTimes,
          settings: settings,
        )
        .then((_) => AppLogger.info('Notifications rescheduled'))
        .catchError(
          (Object e) => AppLogger.error('scheduleNotifications error', e),
        );
  }

  /// Start countdown timer to next prayer
  void _startCountdown() {
    _countdownTimer?.cancel();
    _updateTimeRemaining();

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTimeRemaining(),
    );
  }

  /// Update time remaining to next prayer
  void _updateTimeRemaining() {
    if (!mounted) return;
    final prayerTimes = state.prayerTimes;
    if (prayerTimes == null) return;

    final nextPrayer = getNextPrayerUseCase(prayerTimes);
    final now = DateTime.now();
    // After Isha, getNextPrayerUseCase returns today's Fajr (already past);
    // roll over to tomorrow so the countdown keeps ticking instead of
    // clamping to zero.
    final targetTime = nextPrayer.time.isAfter(now)
        ? nextPrayer.time
        : nextPrayer.time.add(const Duration(days: 1));
    final remaining = targetTime.difference(now);

    state = state.copyWith(
      nextPrayer: nextPrayer,
      timeRemaining: remaining,
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}
