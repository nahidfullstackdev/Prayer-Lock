import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/dua_dhikr/data/datasources/dua_local_data_source.dart';
import 'package:prayer_lock/features/dua_dhikr/data/repositories/dua_repository_impl.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/repositories/dua_repository.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/get_dua_categories.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/get_duas_by_category.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/usecases/search_duas.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/providers/dua_categories_notifier.dart';
import 'package:prayer_lock/features/dua_dhikr/presentation/providers/dua_list_notifier.dart';

// ── Data sources ──────────────────────────────────────────────────────────────

final duaLocalDataSourceProvider = Provider<DuaLocalDataSource>((ref) {
  return DuaLocalDataSource();
});

// ── Repository ────────────────────────────────────────────────────────────────

final duaRepositoryProvider = Provider<DuaRepository>((ref) {
  return DuaRepositoryImpl(
    localDataSource: ref.read(duaLocalDataSourceProvider),
  );
});

// ── Use cases ─────────────────────────────────────────────────────────────────

final getDuaCategoriesUseCaseProvider = Provider<GetDuaCategories>((ref) {
  return GetDuaCategories(ref.read(duaRepositoryProvider));
});

final getDuasByCategoryUseCaseProvider = Provider<GetDuasByCategory>((ref) {
  return GetDuasByCategory(ref.read(duaRepositoryProvider));
});

final searchDuasUseCaseProvider = Provider<SearchDuas>((ref) {
  return SearchDuas(ref.read(duaRepositoryProvider));
});

// ── State notifiers ───────────────────────────────────────────────────────────

final duaCategoriesProvider =
    StateNotifierProvider<DuaCategoriesNotifier, DuaCategoriesState>(
  (ref) => DuaCategoriesNotifier(
    getDuaCategories: ref.read(getDuaCategoriesUseCaseProvider),
  ),
);

/// Family provider keyed by category ID.
final duaListProvider =
    StateNotifierProvider.family<DuaListNotifier, DuaListState, String>(
  (ref, categoryId) => DuaListNotifier(
    categoryId: categoryId,
    getDuasByCategory: ref.read(getDuasByCategoryUseCaseProvider),
    searchDuas: ref.read(searchDuasUseCaseProvider),
  ),
);

// ── Tasbih counter ────────────────────────────────────────────────────────────

class TasbihState {
  const TasbihState({this.count = 0, this.target = 33});

  final int count;
  final int target;

  TasbihState copyWith({int? count, int? target}) => TasbihState(
        count: count ?? this.count,
        target: target ?? this.target,
      );
}

class TasbihNotifier extends StateNotifier<TasbihState> {
  TasbihNotifier() : super(const TasbihState());

  void increment() {
    if (state.count < state.target) {
      state = state.copyWith(count: state.count + 1);
    }
  }

  void reset() => state = state.copyWith(count: 0);

  void setTarget(int target) => state = TasbihState(count: 0, target: target);
}

final tasbihProvider =
    StateNotifierProvider<TasbihNotifier, TasbihState>((ref) {
  return TasbihNotifier();
});
