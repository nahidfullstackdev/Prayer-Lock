import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/dua_dhikr/data/datasources/dua_local_data_source.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/repositories/dua_repository.dart';

class DuaRepositoryImpl implements DuaRepository {
  const DuaRepositoryImpl({required this.localDataSource});

  final DuaLocalDataSource localDataSource;

  @override
  Future<Either<Failure, List<DuaCategory>>> getDuaCategories() async {
    try {
      final models = await localDataSource.getCategories();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      AppLogger.error('Failed to load dua categories', e, st);
      return Left(CacheFailure('Failed to load dua categories: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Dua>>> getDuasByCategory(
    String categoryId,
  ) async {
    try {
      final models = await localDataSource.getDuasByCategory(categoryId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      AppLogger.error('Failed to load duas for category $categoryId', e, st);
      return Left(CacheFailure('Failed to load duas: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Dua>>> searchDuas(String query) async {
    try {
      final models = await localDataSource.searchDuas(query);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      AppLogger.error('Failed to search duas for "$query"', e, st);
      return Left(CacheFailure('Search failed: $e'));
    }
  }
}
