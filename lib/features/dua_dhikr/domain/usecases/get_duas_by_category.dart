import 'package:dartz/dartz.dart';
import 'package:prayer_lock/core/errors/failures.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua.dart';
import 'package:prayer_lock/features/dua_dhikr/domain/repositories/dua_repository.dart';

class GetDuasByCategory {
  const GetDuasByCategory(this._repository);

  final DuaRepository _repository;

  Future<Either<Failure, List<Dua>>> call(String categoryId) =>
      _repository.getDuasByCategory(categoryId);
}
