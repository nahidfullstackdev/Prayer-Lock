import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/get_hadiths.dart';
import 'package:prayer_lock/features/hadith/domain/usecases/search_hadiths.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class HadithListState {
  const HadithListState({
    this.hadiths = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSearching = false,
    this.searchQuery = '',
    this.currentPage = 0,
    this.hasMore = true,
    this.errorMessage,
  });

  final List<Hadith> hadiths;
  final List<Hadith> searchResults;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSearching;
  final String searchQuery;
  final int currentPage;
  final bool hasMore;
  final String? errorMessage;

  bool get isInSearchMode => searchQuery.isNotEmpty;

  HadithListState copyWith({
    List<Hadith>? hadiths,
    List<Hadith>? searchResults,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSearching,
    String? searchQuery,
    int? currentPage,
    bool? hasMore,
    String? errorMessage,
  }) =>
      HadithListState(
        hadiths: hadiths ?? this.hadiths,
        searchResults: searchResults ?? this.searchResults,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isSearching: isSearching ?? this.isSearching,
        searchQuery: searchQuery ?? this.searchQuery,
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

/// [isPro] controls whether all pages are accessible or just the first.
class HadithListNotifier extends StateNotifier<HadithListState> {
  HadithListNotifier({
    required this.collection,
    required this.isPro,
    required this.getHadithsUseCase,
    required this.searchHadithsUseCase,
  }) : super(const HadithListState());

  final String collection;
  final bool isPro;
  final GetHadithsUseCase getHadithsUseCase;
  final SearchHadithsUseCase searchHadithsUseCase;

  int get _pageSize =>
      isPro ? ApiConstants.hadithProPageSize : ApiConstants.hadithFreePageSize;

  /// Load the first page. Call on screen init.
  Future<void> loadFirstPage() async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      hadiths: const [],
      currentPage: 0,
      hasMore: true,
      errorMessage: null,
    );

    final result = await getHadithsUseCase(
      collection: collection,
      page: 1,
      limit: _pageSize,
    );

    result.fold(
      (failure) {
        AppLogger.error(
          'Failed to load hadiths ($collection): ${failure.message}',
        );
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
      },
      (hadiths) {
        state = state.copyWith(
          hadiths: hadiths,
          isLoading: false,
          currentPage: 1,
          // Free users can only see the first page.
          hasMore: isPro && hadiths.length >= _pageSize,
        );
      },
    );
  }

  /// Load the next page (Pro only). No-op for free users.
  Future<void> loadNextPage() async {
    if (!isPro || !state.hasMore || state.isLoadingMore || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;

    final result = await getHadithsUseCase(
      collection: collection,
      page: nextPage,
      limit: _pageSize,
    );

    result.fold(
      (failure) {
        AppLogger.error('Failed to load more hadiths: ${failure.message}');
        state = state.copyWith(isLoadingMore: false);
      },
      (newHadiths) {
        state = state.copyWith(
          hadiths: [...state.hadiths, ...newHadiths],
          isLoadingMore: false,
          currentPage: nextPage,
          hasMore: newHadiths.length >= _pageSize,
        );
      },
    );
  }

  /// Search cached hadiths in SQLite. Empty query clears search mode.
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query);
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: const []);
      return;
    }

    state = state.copyWith(isSearching: true);
    final result = await searchHadithsUseCase(
      query: query.trim(),
      collection: collection,
    );
    result.fold(
      (_) => state = state.copyWith(isSearching: false),
      (results) => state = state.copyWith(
        searchResults: results,
        isSearching: false,
      ),
    );
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: const []);
  }
}
