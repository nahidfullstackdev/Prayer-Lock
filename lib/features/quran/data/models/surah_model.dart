import 'package:prayer_lock/features/quran/domain/entities/surah.dart';

/// Surah data model with JSON serialization
///
/// Extends Surah entity and adds serialization methods
class SurahModel extends Surah {
  const SurahModel({
    required super.id,
    required super.nameArabic,
    required super.nameTransliteration,
    required super.nameEnglish,
    required super.revelationPlace,
    required super.totalAyahs,
  });

  /// Create SurahModel from JSON (API response)
  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      id: json['number'] as int,
      nameArabic: json['name'] as String,
      nameTransliteration: json['englishName'] as String,
      nameEnglish: json['englishNameTranslation'] as String,
      revelationPlace: json['revelationType'] as String,
      totalAyahs: json['numberOfAyahs'] as int,
    );
  }

  /// Convert SurahModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'number': id,
      'name': nameArabic,
      'englishName': nameTransliteration,
      'englishNameTranslation': nameEnglish,
      'revelationType': revelationPlace,
      'numberOfAyahs': totalAyahs,
    };
  }

  /// Create SurahModel from SQLite map
  factory SurahModel.fromMap(Map<String, dynamic> map) {
    return SurahModel(
      id: map['id'] as int,
      nameArabic: map['name_arabic'] as String,
      nameTransliteration: map['name_transliteration'] as String,
      nameEnglish: map['name_english'] as String,
      revelationPlace: map['revelation_place'] as String,
      totalAyahs: map['total_ayahs'] as int,
    );
  }

  /// Convert SurahModel to SQLite map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_arabic': nameArabic,
      'name_transliteration': nameTransliteration,
      'name_english': nameEnglish,
      'revelation_place': revelationPlace,
      'total_ayahs': totalAyahs,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Convert SurahModel to Surah entity
  Surah toEntity() {
    return Surah(
      id: id,
      nameArabic: nameArabic,
      nameTransliteration: nameTransliteration,
      nameEnglish: nameEnglish,
      revelationPlace: revelationPlace,
      totalAyahs: totalAyahs,
    );
  }

  /// Create SurahModel from Surah entity
  factory SurahModel.fromEntity(Surah surah) {
    return SurahModel(
      id: surah.id,
      nameArabic: surah.nameArabic,
      nameTransliteration: surah.nameTransliteration,
      nameEnglish: surah.nameEnglish,
      revelationPlace: surah.revelationPlace,
      totalAyahs: surah.totalAyahs,
    );
  }
}
