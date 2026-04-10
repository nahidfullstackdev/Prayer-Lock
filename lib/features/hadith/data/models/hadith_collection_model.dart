import 'package:prayer_lock/features/hadith/domain/entities/hadith_collection.dart';

/// Data model for a HadithCollection — handles JSON parsing and SQLite mapping.
class HadithCollectionModel extends HadithCollection {
  const HadithCollectionModel({
    required super.name,
    required super.title,
    required super.titleArabic,
    required super.totalHadith,
    super.availableLanguages,
  });

  // ── API (fawazahmed0/hadith-api — editions.min.json) ─────────────────────

  /// Parses one book entry from the editions.min.json response.
  ///
  /// [bookKey] e.g. 'bukhari'; [bookData] is the map value for that key, e.g.:
  /// ```json
  /// { "name": "Sahih al Bukhari", "collection": [ {"name": "ara-bukhari", ...} ] }
  /// ```
  factory HadithCollectionModel.fromEditionsJson(
    String bookKey,
    Map<String, dynamic> bookData,
  ) {
    final title = (bookData['name'] as String?) ?? bookKey;
    final rawCollections = (bookData['collection'] as List<dynamic>?) ?? [];

    // Extract unique language codes from edition names like 'ara-bukhari'.
    // Skip diacritics-removed variants ending in digits (e.g. 'ara-bukhari1').
    final languages = <String>[];
    for (final c in rawCollections) {
      final cMap = c as Map<String, dynamic>;
      final editionName = (cMap['name'] as String?) ?? '';
      final expectedSuffix = '-$bookKey';
      if (editionName.endsWith(expectedSuffix)) {
        final langCode = editionName.substring(
          0,
          editionName.length - expectedSuffix.length,
        );
        // Only accept 2–3 char alpha codes with no numeric suffix
        if (langCode.isNotEmpty &&
            RegExp(r'^[a-z]{2,3}$').hasMatch(langCode) &&
            !languages.contains(langCode)) {
          languages.add(langCode);
        }
      }
    }

    return HadithCollectionModel(
      name: bookKey,
      title: title,
      titleArabic: _arabicTitles[bookKey] ?? title,
      totalHadith: _hadithCounts[bookKey] ?? 0,
      availableLanguages: languages,
    );
  }

  // ── SQLite ────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'name': name,
        'title': title,
        'title_arabic': titleArabic,
        'total_hadith': totalHadith,
        'available_languages': availableLanguages.join(','),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory HadithCollectionModel.fromMap(Map<String, dynamic> map) =>
      HadithCollectionModel(
        name: map['name'] as String,
        title: map['title'] as String,
        titleArabic: map['title_arabic'] as String,
        totalHadith: map['total_hadith'] as int,
        availableLanguages:
            ((map['available_languages'] as String?) ?? '')
                .split(',')
                .where((s) => s.isNotEmpty)
                .toList(),
      );

  HadithCollection toEntity() => HadithCollection(
        name: name,
        title: title,
        titleArabic: titleArabic,
        totalHadith: totalHadith,
        availableLanguages: availableLanguages,
      );

  // ── Static metadata ───────────────────────────────────────────────────────

  /// Known Arabic titles for each book key.
  static const Map<String, String> _arabicTitles = {
    'bukhari': 'صحيح البخاري',
    'muslim': 'صحيح مسلم',
    'tirmidhi': 'جامع الترمذي',
    'abudawud': 'سنن أبي داود',
    'nasai': 'سنن النسائي',
    'ibnmajah': 'سنن ابن ماجه',
    'malik': 'موطأ مالك',
    'nawawi': 'الأربعون النووية',
    'qudsi': 'الأحاديث القدسية',
    'dehlawi': 'أربعون حديثاً للدهلوي',
  };

  /// Known total hadith counts per book key.
  static const Map<String, int> _hadithCounts = {
    'bukhari': 7563,
    'muslim': 3033,
    'tirmidhi': 3956,
    'abudawud': 5274,
    'nasai': 5758,
    'ibnmajah': 4341,
    'malik': 1594,
    'nawawi': 42,
    'qudsi': 40,
    'dehlawi': 40,
  };
}
