import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/get_hadith_collections.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class HadithCollectionsState {
  const HadithCollectionsState({
    this.collections = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<HadithCollection> collections;
  final bool isLoading;
  final String? errorMessage;

  HadithCollectionsState copyWith({
    List<HadithCollection>? collections,
    bool? isLoading,
    String? errorMessage,
  }) =>
      HadithCollectionsState(
        collections: collections ?? this.collections,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class HadithCollectionsNotifier extends StateNotifier<HadithCollectionsState> {
  HadithCollectionsNotifier({
    required this.getCollectionsUseCase,
  }) : super(const HadithCollectionsState());

  final GetHadithCollectionsUseCase getCollectionsUseCase;

  Future<void> loadCollections() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await getCollectionsUseCase();
    result.fold(
      (failure) {
        AppLogger.error('Failed to load hadith collections: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (collections) {
        AppLogger.info('Loaded ${collections.length} hadith collections');
        state = state.copyWith(collections: collections, isLoading: false);
      },
    );
  }
}
