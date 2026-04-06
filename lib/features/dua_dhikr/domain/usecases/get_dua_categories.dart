import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/repositories/dua_repository.dart';

class GetDuaCategories {
  const GetDuaCategories(this._repository);

  final DuaRepository _repository;

  Future<Either<Failure, List<DuaCategory>>> call() =>
      _repository.getDuaCategories();
}
