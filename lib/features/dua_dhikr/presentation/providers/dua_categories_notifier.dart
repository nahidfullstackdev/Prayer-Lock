import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/get_dua_categories.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class DuaCategoriesState {
  const DuaCategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<DuaCategory> categories;
  final bool isLoading;
  final String? errorMessage;

  DuaCategoriesState copyWith({
    List<DuaCategory>? categories,
    bool? isLoading,
    String? errorMessage,
  }) =>
      DuaCategoriesState(
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class DuaCategoriesNotifier extends StateNotifier<DuaCategoriesState> {
  DuaCategoriesNotifier({required this.getDuaCategories})
      : super(const DuaCategoriesState());

  final GetDuaCategories getDuaCategories;

  Future<void> loadCategories() async {
    if (state.categories.isNotEmpty) return; // already loaded
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await getDuaCategories();
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (categories) => state = state.copyWith(
        isLoading: false,
        categories: categories,
      ),
    );
  }
}
