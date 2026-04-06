import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua.dart';

/// Data model for a [Dua] — handles JSON parsing from bundled asset.
class DuaModel extends Dua {
  const DuaModel({
    required super.id,
    required super.categoryId,
    required super.arabic,
    required super.transliteration,
    required super.translation,
    required super.reference,
    super.count,
    super.orderIndex,
  });

  factory DuaModel.fromJson(
    Map<String, dynamic> json,
    String categoryId, {
    int orderIndex = 0,
  }) =>
      DuaModel(
        id: json['id'] as String,
        categoryId: categoryId,
        arabic: json['arabic'] as String,
        transliteration: json['transliteration'] as String,
        translation: json['translation'] as String,
        reference: json['reference'] as String,
        count: (json['count'] as int?) ?? 1,
        orderIndex: orderIndex,
      );

  Dua toEntity() => Dua(
        id: id,
        categoryId: categoryId,
        arabic: arabic,
        transliteration: transliteration,
        translation: translation,
        reference: reference,
        count: count,
        orderIndex: orderIndex,
      );
}
