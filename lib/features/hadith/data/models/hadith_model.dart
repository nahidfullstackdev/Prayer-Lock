import 'dart:convert';

import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';

/// Data model for a Hadith — handles API JSON parsing and SQLite mapping.
///
/// When parsed from the CDN API, [translations] contains a single language key.
/// When read from SQLite, [translations] contains all cached languages.
class HadithModel extends Hadith {
  const HadithModel({
    required super.collection,
    required super.hadithNumber,
    required super.arabicNumber,
    required super.section,
    required super.translations,
    super.grade,
  });

  // ── API (fawazahmed0/hadith-api — editions/{lang}-{book}.min.json) ────────

  /// Parses one item from a CDN edition response hadiths array.
  ///
  /// [langCode] identifies the language of [json['text']].
  /// [sectionLookup] maps hadith_number → section/chapter name.
  static HadithModel fromApiJson(
    Map<String, dynamic> json,
    String collection,
    String langCode,
    Map<int, String> sectionLookup,
  ) {
    final hadithNumber = (json['hadithnumber'] as num?)?.toInt() ?? 0;
    final arabicNumber =
        (json['arabicnumber'] as num?)?.toInt() ?? hadithNumber;
    final text = (json['text'] as String?) ?? '';

    // Grade from grades array (e.g. [{"grade": "Sahih", "graded_by": "..."}])
    final grades = (json['grades'] as List<dynamic>?) ?? [];
    String? grade;
    if (grades.isNotEmpty) {
      grade =
          (grades.first as Map<String, dynamic>)['grade'] as String?;
    }

    final section = sectionLookup[hadithNumber] ?? '';

    return HadithModel(
      collection: collection,
      hadithNumber: hadithNumber,
      arabicNumber: arabicNumber,
      section: section,
      translations: {langCode: text},
      grade: grade,
    );
  }

  // ── SQLite ────────────────────────────────────────────────────────────────

  Map<String, dynamic> toDbMap() => {
        'collection': collection,
        'hadith_number': hadithNumber,
        'arabic_number': arabicNumber,
        'section': section,
        'grade': grade,
        'translations': jsonEncode(translations),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory HadithModel.fromDbMap(Map<String, dynamic> map) {
    final translationsJson = (map['translations'] as String?) ?? '{}';
    Map<String, dynamic> raw;
    try {
      raw = jsonDecode(translationsJson) as Map<String, dynamic>;
    } catch (_) {
      raw = {};
    }
    final translations = raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));

    return HadithModel(
      collection: map['collection'] as String,
      hadithNumber: map['hadith_number'] as int,
      arabicNumber:
          (map['arabic_number'] as int?) ?? (map['hadith_number'] as int),
      section: (map['section'] as String?) ?? '',
      translations: translations,
      grade: map['grade'] as String?,
    );
  }

  Hadith toEntity() => Hadith(
        collection: collection,
        hadithNumber: hadithNumber,
        arabicNumber: arabicNumber,
        section: section,
        translations: translations,
        grade: grade,
      );
}
