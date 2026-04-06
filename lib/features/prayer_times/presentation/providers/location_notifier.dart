import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/repositories/location_repository.dart';
import 'package:prayer_lock/features/prayer_times/domain/usecases/get_current_location.dart';

/// State for user location
class LocationState {
  final LocationData? location;
  final bool isLoading;
  final String? errorMessage;
  final bool isPermissionDenied;

  const LocationState({
    this.location,
    this.isLoading = false,
    this.errorMessage,
    this.isPermissionDenied = false,
  });

  LocationState copyWith({
    LocationData? location,
    bool? isLoading,
    String? errorMessage,
    bool? isPermissionDenied,
  }) {
    return LocationState(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isPermissionDenied: isPermissionDenied ?? this.isPermissionDenied,
    );
  }
}

/// State notifier for managing user location
class LocationNotifier extends StateNotifier<LocationState> {
  final GetCurrentLocationUseCase getCurrentLocationUseCase;
  final LocationRepository locationRepository;

  LocationNotifier({
    required this.getCurrentLocationUseCase,
    required this.locationRepository,
  }) : super(const LocationState()) {
    _loadCachedLocation();
  }

  /// Load cached location first, then fetch fresh GPS
  Future<void> _loadCachedLocation() async {
    final cachedResult = await locationRepository.getLastKnownLocation();
    cachedResult.fold(
      (_) {},
      (cached) {
        if (cached != null) {
          state = state.copyWith(location: cached);
          AppLogger.info('Loaded cached location: ${cached.cityName}');
        }
      },
    );

    // Then fetch fresh location
    await fetchLocation();
  }

  /// Fetch current GPS location with reverse geocoding
  Future<void> fetchLocation() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Fetching user location...');

    final result = await getCurrentLocationUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Failed to get location: ${failure.message}');
        final isPermission =
            failure.message.toLowerCase().contains('permission') ||
                failure.message.toLowerCase().contains('denied');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          isPermissionDenied: isPermission,
        );
      },
      (location) {
        AppLogger.info(
          'Location resolved: ${location.cityName}, ${location.countryName}',
        );
        state = state.copyWith(
          location: location,
          isLoading: false,
          errorMessage: null,
          isPermissionDenied: false,
        );
      },
    );
  }

  /// Refresh location (user-triggered)
  Future<void> refresh() async {
    await fetchLocation();
  }
}
