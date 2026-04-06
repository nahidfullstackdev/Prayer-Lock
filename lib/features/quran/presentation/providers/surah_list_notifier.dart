import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/domain/entities/surah.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_all_surahs.dart';

/// State for Surah list
class SurahListState {
  final List<Surah> surahs;
  final bool isLoading;
  final String? errorMessage;

  const SurahListState({
    this.surahs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SurahListState copyWith({
    List<Surah>? surahs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SurahListState(
      surahs: surahs ?? this.surahs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// State notifier for Surah list
class SurahListNotifier extends StateNotifier<SurahListState> {
  final GetAllSurahsUseCase getAllSurahsUseCase;

  SurahListNotifier({
    required this.getAllSurahsUseCase,
  }) : super(const SurahListState()) {
    loadSurahs();
  }

  /// Load all Surahs
  Future<void> loadSurahs() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Loading Surahs...');

    final result = await getAllSurahsUseCase();

    result.fold(
      (failure) {
        AppLogger.error('Failed to load Surahs: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (surahs) {
        AppLogger.info('Loaded ${surahs.length} Surahs successfully');
        state = state.copyWith(
          surahs: surahs,
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  /// Refresh Surahs
  Future<void> refresh() async {
    await loadSurahs();
  }
}
