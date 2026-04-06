import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';
import 'package:prayer_lock/features/quran/domain/usecases/search_ayahs.dart';

/// State for search
class SearchState {
  final List<Ayah> results;
  final bool isLoading;
  final String? errorMessage;
  final String query;

  const SearchState({
    this.results = const [],
    this.isLoading = false,
    this.errorMessage,
    this.query = '',
  });

  SearchState copyWith({
    List<Ayah>? results,
    bool? isLoading,
    String? errorMessage,
    String? query,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      query: query ?? this.query,
    );
  }
}

/// State notifier for search
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchAyahsUseCase searchAyahsUseCase;

  SearchNotifier({
    required this.searchAyahsUseCase,
  }) : super(const SearchState());

  /// Search Ayahs by query
  Future<void> search(String query) async {
    // Update query immediately
    state = state.copyWith(query: query);

    // Clear results if query is too short
    if (query.trim().isEmpty || query.trim().length < 2) {
      state = state.copyWith(
        results: [],
        isLoading: false,
        errorMessage: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    AppLogger.info('Searching for: "$query"');

    final result = await searchAyahsUseCase(query);

    result.fold(
      (failure) {
        AppLogger.error('Search failed: ${failure.message}');
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
        );
      },
      (results) {
        AppLogger.info('Found ${results.length} results for "$query"');
        state = state.copyWith(
          results: results,
          isLoading: false,
          errorMessage: null,
        );
      },
    );
  }

  /// Clear search results
  void clear() {
    state = const SearchState();
    AppLogger.debug('Search cleared');
  }
}
