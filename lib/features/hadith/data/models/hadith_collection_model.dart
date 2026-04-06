import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';

/// Data model for a HadithCollection — handles JSON parsing and SQLite mapping.
class HadithCollectionModel extends HadithCollection {
  const HadithCollectionModel({
    required super.name,
    required super.title,
    required super.titleArabic,
    required super.totalHadith,
  });

  // ── API (sunnah.com) ─────────────────────────────────────────────────────

  /// Parses one item from GET /collections response data array.
  factory HadithCollectionModel.fromJson(Map<String, dynamic> json) {
    final langs = (json['collection'] as List<dynamic>?) ?? [];

    String enTitle = '';
    String arTitle = '';
    for (final lang in langs) {
      final map = lang as Map<String, dynamic>;
      if (map['lang'] == 'en') enTitle = (map['title'] as String?) ?? '';
      if (map['lang'] == 'ar') arTitle = (map['title'] as String?) ?? '';
    }

    return HadithCollectionModel(
      name: (json['name'] as String?) ?? '',
      title: enTitle,
      titleArabic: arTitle,
      totalHadith: (json['totalAvailableHadith'] as int?) ??
          (json['totalHadith'] as int?) ??
          0,
    );
  }

  // ── SQLite ────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'title_arabic': titleArabic,
        'total_hadith': totalHadith,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory HadithCollectionModel.fromMap(Map<String, dynamic> map) =>
      HadithCollectionModel(
        name: map['name'] as String,
        title: map['title'] as String,
        titleArabic: map['title_arabic'] as String,
        totalHadith: map['total_hadith'] as int,
      );

  HadithCollection toEntity() => HadithCollection(
        name: name,
        title: title,
        titleArabic: titleArabic,
        totalHadith: totalHadith,
      );
}
