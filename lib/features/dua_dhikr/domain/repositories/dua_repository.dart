import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';

abstract class DuaRepository {
  Future<Either<Failure, List<DuaCategory>>> getDuaCategories();
  Future<Either<Failure, List<Dua>>> getDuasByCategory(String categoryId);
  Future<Either<Failure, List<Dua>>> searchDuas(String query);
}
