import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';
import 'package:prayer_lock/features/quran/domain/usecases/get_surah_by_id.dart';
import 'package:prayer_lock/features/quran/domain/usecases/save_last_read.dart';

/// State for Surah detail (Ayahs)
class SurahDetailState {
  final List<Ayah> ayahs;
  final bool isLoading;
  final String? errorMessage;

  const SurahDetailState({
    this.ayahs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  SurahDetailState copyWith({
    List<Ayah>? ayahs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return SurahDetailState(
      ayahs: ayahs ?? this.ayahs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// State notifier for Surah detail
class SurahDetailNotifier extends StateNotifier<SurahDetailState> {
  final int surahId;
  final GetSurahByIdUseCase getSurahByIdUseCase;
  final SaveLastReadUseCase saveLastReadUseCase;

  SurahDetailNotifier({
    required this.surahId,
    required this.getSurahByIdUseCase,
    required this.saveLastReadUseCase,
  }) : super(const SurahDetailState()) {
    loadAyahs();
  }

  /// Load Ayahs for the Surah
  Future<void> loadAyahs() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Loading Ayahs for Surah $surahId...');

    final result = await getSurahByIdUseCase(surahId);

    result.fold(
      (failure) {
        AppLogger.error('Failed to load Ayahs: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (ayahs) {
        AppLogger.info('Loaded ${ayahs.length} Ayahs for Surah $surahId');
        state = state.copyWith(
          ayahs: ayahs,
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  /// Save last read position
  Future<void> saveLastReadPosition(int ayahId, String surahName, int ayahNumber) async {
    final lastRead = LastRead(
      surahId: surahId,
      ayahId: ayahId,
      surahName: surahName,
      ayahNumber: ayahNumber,
      updatedAt: DateTime.now(),
    );

    final result = await saveLastReadUseCase(lastRead);

    result.fold(
      (failure) {
        AppLogger.error('Failed to save last read: ${failure.message}');
      },
      (_) {
        AppLogger.debug('Saved last read: Surah $surahId, Ayah $ayahNumber');
      },
    );
  }

  /// Refresh Ayahs
  Future<void> refresh() async {
    await loadAyahs();
  }
}
