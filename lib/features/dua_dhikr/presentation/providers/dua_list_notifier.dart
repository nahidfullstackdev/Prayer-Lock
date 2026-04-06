import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/get_duas_by_category.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/search_duas.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class DuaListState {
  const DuaListState({
    this.duas = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.searchResults = const [],
    this.isSearching = false,
  });

  final List<Dua> duas;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final List<Dua> searchResults;
  final bool isSearching;

  bool get hasSearch => searchQuery.isNotEmpty;

  List<Dua> get displayed => hasSearch ? searchResults : duas;

  DuaListState copyWith({
    List<Dua>? duas,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    List<Dua>? searchResults,
    bool? isSearching,
  }) =>
      DuaListState(
        duas: duas ?? this.duas,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        searchQuery: searchQuery ?? this.searchQuery,
        searchResults: searchResults ?? this.searchResults,
        isSearching: isSearching ?? this.isSearching,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DuaListNotifier extends StateNotifier<DuaListState> {
  DuaListNotifier({
    required this.categoryId,
    required this.getDuasByCategory,
    required this.searchDuas,
  }) : super(const DuaListState());

  final String categoryId;
  final GetDuasByCategory getDuasByCategory;
  final SearchDuas searchDuas;

  Future<void> loadDuas() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await getDuasByCategory(categoryId);
    result.fold(
      (failure) => state =
          state.copyWith(isLoading: false, errorMessage: failure.message),
      (duas) => state = state.copyWith(isLoading: false, duas: duas),
    );
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }
    state = state.copyWith(searchQuery: query, isSearching: true);
    final result = await searchDuas(query);
    result.fold(
      (_) => state = state.copyWith(isSearching: false),
      (results) => state = state.copyWith(
        searchResults: results,
        isSearching: false,
      ),
    );
  }

  void clearSearch() => state = state.copyWith(
        searchQuery: '',
        searchResults: const [],
        isSearching: false,
      );
}
