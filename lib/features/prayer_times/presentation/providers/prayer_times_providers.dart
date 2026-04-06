import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/network/dio_client.dart';
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
  return PrayerTimesRepositoryImpl(
    remoteDataSource: ref.read(prayerTimesRemoteDataSourceProvider),
    localDataSource: ref.read(prayerTimesLocalDataSourceProvider),
  );
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
  );

  // Re-fetch whenever the calculation method changes.
  ref.listen(
    prayerSettingsProvider.select((s) => s.settings.calculationMethod),
    (_, __) => notifier.refresh(),
  );

  return notifier;
});

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
