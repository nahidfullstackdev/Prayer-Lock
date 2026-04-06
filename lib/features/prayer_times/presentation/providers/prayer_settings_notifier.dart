import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/update_prayer_settings.dart';

/// State for Prayer Settings
class PrayerSettingsState {
  final PrayerSettings settings;
  final bool isLoading;
  final String? errorMessage;

  const PrayerSettingsState({
    this.settings = const PrayerSettings(),
    this.isLoading = false,
    this.errorMessage,
  });

  PrayerSettingsState copyWith({
    PrayerSettings? settings,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PrayerSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// State notifier for prayer settings
class PrayerSettingsNotifier extends StateNotifier<PrayerSettingsState> {
  final GetPrayerSettingsUseCase getPrayerSettingsUseCase;
  final UpdatePrayerSettingsUseCase updatePrayerSettingsUseCase;

  PrayerSettingsNotifier({
    required this.getPrayerSettingsUseCase,
    required this.updatePrayerSettingsUseCase,
  }) : super(const PrayerSettingsState()) {
    loadSettings();
  }

  /// Load settings from local storage
  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Loading prayer settings...');

    final result = await getPrayerSettingsUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Failed to load settings: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (settings) {
        AppLogger.info('Prayer settings loaded: $settings');
        state = state.copyWith(
          settings: settings,
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  /// Update calculation method
  Future<void> updateCalculationMethod(int method) async {
    final updated = state.settings.copyWith(calculationMethod: method);
    await _saveSettings(updated);
  }

  /// Update madhab
  Future<void> updateMadhab(int madhab) async {
    final updated = state.settings.copyWith(madhab: madhab);
    await _saveSettings(updated);
  }

  /// Toggle notification for a specific prayer
  Future<void> toggleNotification(PrayerName prayer) async {
    final currentMap = Map<PrayerName, bool>.from(state.settings.notificationsEnabled);
    currentMap[prayer] = !(currentMap[prayer] ?? true);
    final updated = state.settings.copyWith(notificationsEnabled: currentMap);
    await _saveSettings(updated);
  }

  /// Update notification minutes before
  Future<void> updateMinutesBefore(int minutes) async {
    final updated = state.settings.copyWith(notificationMinutesBefore: minutes);
    await _saveSettings(updated);
  }

  /// Save settings to local storage
  Future<void> _saveSettings(PrayerSettings settings) async {
    final result = await updatePrayerSettingsUseCase(settings);

    result.fold(
      (failure) {
        AppLogger.error('Failed to save settings: ${failure.message}');
        state = state.copyWith(errorMessage: failure.message);
      },
      (_) {
        AppLogger.info('Settings saved: $settings');
        state = state.copyWith(settings: settings, errorMessage: null);
      },
    );
  }
}
