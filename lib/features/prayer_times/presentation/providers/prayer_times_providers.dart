import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/network/connectivity_service.dart';
import 'package:prayer_lock/core/network/dio_client.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/location_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_local_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/prayer_times_remote_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/datasources/qibla_data_source.dart';
import 'package:prayer_lock/features/prayer_times/data/repositories/location_repository_impl.dart';
import 'package:prayer_lock/features/prayer_times/data/repositories/prayer_times_repository_impl.dart';
import 'package:prayer_lock/features/prayer_times/data/repositories/qibla_repository_impl.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/location_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/notification_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/prayer_times_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/qibla_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_current_location.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_next_prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_prayer_times.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_qibla_direction.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/schedule_prayer_notifications.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/update_prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/location_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/notification_service.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_settings_notifier.dart';
import 'package:prayer_lock/features/prayer_times/presentation/providers/prayer_times_notifier.dart';

// ==================== Infrastructure Providers ====================

/// Connectivity service — wraps `connectivity_plus`. Disposed with the
/// provider scope so the underlying StreamController never leaks across
/// hot restarts.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final svc = ConnectivityService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Distinct stream of online/offline transitions. The notifier listens
/// here to trigger an automatic refresh when the network comes back.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onStatusChange;
});

// ==================== Data Source Providers ====================

/// Prayer times local data source (Hive)
final prayerTimesLocalDataSourceProvider =
    Provider<PrayerTimesLocalDataSource>((ref) {
  return PrayerTimesLocalDataSource();
});

/// Prayer times remote data source (Aladhan API)
final prayerTimesRemoteDataSourceProvider =
    Provider<PrayerTimesRemoteDataSource>((ref) {
  return PrayerTimesRemoteDataSource(dio: DioClient.instance.dio);
});

/// Location data source (Geolocator)
final locationDataSourceProvider = Provider<LocationDataSource>((ref) {
  return LocationDataSource();
});

/// Qibla data source
final qiblaDataSourceProvider = Provider<QiblaDataSource>((ref) {
  return QiblaDataSource();
});

// ==================== Repository Providers ====================

/// Prayer times repository
final prayerTimesRepositoryProvider = Provider<PrayerTimesRepository>((ref) {
  final repo = PrayerTimesRepositoryImpl(
    remoteDataSource: ref.read(prayerTimesRemoteDataSourceProvider),
    localDataSource: ref.read(prayerTimesLocalDataSourceProvider),
    connectivity: ref.read(connectivityServiceProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Location repository
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(
    dataSource: ref.read(locationDataSourceProvider),
    localDataSource: ref.read(prayerTimesLocalDataSourceProvider),
  );
});

/// Qibla repository
final qiblaRepositoryProvider = Provider<QiblaRepository>((ref) {
  return QiblaRepositoryImpl(
    dataSource: ref.read(qiblaDataSourceProvider),
  );
});

/// Notification repository (NotificationService implements NotificationRepository)
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ref.read(notificationServiceProvider);
});

// ==================== UseCase Providers ====================

/// Get prayer times use case
final getPrayerTimesUseCaseProvider = Provider<GetPrayerTimesUseCase>((ref) {
  return GetPrayerTimesUseCase(
    prayerTimesRepository: ref.read(prayerTimesRepositoryProvider),
    locationRepository: ref.read(locationRepositoryProvider),
  );
});

/// Get next prayer use case
final getNextPrayerUseCaseProvider = Provider<GetNextPrayerUseCase>((ref) {
  return const GetNextPrayerUseCase();
});

/// Get current location use case
final getCurrentLocationUseCaseProvider =
    Provider<GetCurrentLocationUseCase>((ref) {
  return GetCurrentLocationUseCase(
    repository: ref.read(locationRepositoryProvider),
  );
});

/// Get prayer settings use case
final getPrayerSettingsUseCaseProvider =
    Provider<GetPrayerSettingsUseCase>((ref) {
  return GetPrayerSettingsUseCase(ref.read(prayerTimesRepositoryProvider));
});

/// Update prayer settings use case
final updatePrayerSettingsUseCaseProvider =
    Provider<UpdatePrayerSettingsUseCase>((ref) {
  return UpdatePrayerSettingsUseCase(ref.read(prayerTimesRepositoryProvider));
});

/// Get qibla direction use case
final getQiblaDirectionUseCaseProvider =
    Provider<GetQiblaDirectionUseCase>((ref) {
  return GetQiblaDirectionUseCase(
    repository: ref.read(qiblaRepositoryProvider),
  );
});

/// Schedule prayer notifications use case
final schedulePrayerNotificationsUseCaseProvider =
    Provider<SchedulePrayerNotificationsUseCase>((ref) {
  return SchedulePrayerNotificationsUseCase(
    ref.read(notificationRepositoryProvider),
  );
});

// ==================== Service Providers ====================

/// Notification service (singleton — initialised in main.dart)
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// ==================== State Notifier Providers ====================

/// Prayer times state notifier provider
final prayerTimesProvider =
    StateNotifierProvider<PrayerTimesNotifier, PrayerTimesState>((ref) {
  final notifier = PrayerTimesNotifier(
    getPrayerTimesUseCase: ref.read(getPrayerTimesUseCaseProvider),
    getNextPrayerUseCase: ref.read(getNextPrayerUseCaseProvider),
    notificationRepository: ref.read(notificationRepositoryProvider),
    prayerTimesRepository: ref.read(prayerTimesRepositoryProvider),
    // Notifier reads current settings via this callback so it can always
    // schedule on a successful prayer-times load — even on the very first
    // run before the user has opened the notification settings sheet.
    readSettings: () => ref.read(prayerSettingsProvider).settings,
  );

  // Auto-refresh when the network comes back after being offline. The first
  // emission of `isOnlineProvider` is the *current* status, so we only
  // trigger when we have a real prev→next transition (false → true).
  ref.listen<AsyncValue<bool>>(isOnlineProvider, (prev, next) {
    final wasOffline = prev?.valueOrNull == false;
    final isOnline = next.valueOrNull == true;
    if (wasOffline && isOnline) {
      AppLogger.info('Network restored — refreshing prayer times');
      notifier.refresh(settings: ref.read(prayerSettingsProvider).settings);
    }
  });

  // Re-fetch whenever the calculation method changes (changes the API result).
  ref.listen(
    prayerSettingsProvider.select((s) => s.settings.calculationMethod),
    (_, __) => notifier.refresh(
      settings: ref.read(prayerSettingsProvider).settings,
    ),
  );

  // Reschedule whenever any setting that affects alarms changes:
  //   • per-prayer toggles (notificationsEnabled)
  //   • notificationMinutesBefore
  //   • adhanType
  //   • madhab (changes the prayer time itself, hence the alarm time)
  // This also catches the cold-start race where prayerSettings finishes
  // loading from Hive *after* the notifier has already loaded prayer times.
  // The settings sheet's explicit `_reschedule(ref)` is still safe — the
  // native pipeline cancels-then-reschedules, so duplicates are not possible.
  ref.listen(prayerSettingsProvider, (prev, next) {
    if (next.isLoading) return;

    if (prev != null) {
      final p = prev.settings;
      final n = next.settings;
      final unchanged = p.madhab == n.madhab &&
          p.notificationMinutesBefore == n.notificationMinutesBefore &&
          p.adhanType == n.adhanType &&
          _mapEq(p.notificationsEnabled, n.notificationsEnabled);
      if (unchanged) return;
    }
    // scheduleNotifications no-ops internally when prayerTimes is null,
    // so we don't need to (and can't, due to protected `state`) check it
    // from inside this provider factory.
    notifier.scheduleNotifications(next.settings);
  });

  return notifier;
});

bool _mapEq<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

/// Prayer settings state notifier provider
final prayerSettingsProvider =
    StateNotifierProvider<PrayerSettingsNotifier, PrayerSettingsState>((ref) {
  return PrayerSettingsNotifier(
    getPrayerSettingsUseCase: ref.read(getPrayerSettingsUseCaseProvider),
    updatePrayerSettingsUseCase: ref.read(updatePrayerSettingsUseCaseProvider),
  );
});

/// User location state notifier provider
final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(
    getCurrentLocationUseCase: ref.read(getCurrentLocationUseCaseProvider),
    locationRepository: ref.read(locationRepositoryProvider),
  );
});
