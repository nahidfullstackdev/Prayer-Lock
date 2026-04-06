import 'package:prayer_lock/features/dua_dhikr/domain/entities/dua_category.dart';

/// Data model for a [DuaCategory] — parses a category object from the bundled JSON.
class DuaCategoryModel {
  const DuaCategoryModel({
    required this.id,
    required this.name,
    required this.arabic,
    required this.description,
    required this.iconName,
    required this.isPro,
    required this.duaCount,
    required this.orderIndex,
  });

  final String id;
  final String name;
  final String arabic;
  final String description;
  final String iconName;
  final bool isPro;
  final int duaCount;
  final int orderIndex;

  factory DuaCategoryModel.fromJson(Map<String, dynamic> json, int index) {
    final duas = (json['duas'] as List<dynamic>?) ?? [];
    return DuaCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      arabic: json['arabic'] as String,
      description: (json['description'] as String?) ?? '',
      iconName: (json['iconName'] as String?) ?? 'auto_awesome_rounded',
      isPro: (json['isPro'] as bool?) ?? false,
      duaCount: duas.length,
      orderIndex: index,
    );
  }

  DuaCategory toEntity() => DuaCategory(
        id: id,
        name: name,
        arabic: arabic,
        description: description,
        iconName: iconName,
        isPro: isPro,
        duaCount: duaCount,
        orderIndex: orderIndex,
      );
}
