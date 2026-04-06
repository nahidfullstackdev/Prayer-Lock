import 'package:prayer_lock/features/quran/domain/entities/ayah.dart';

/// Ayah data model with JSON serialization
///
/// Extends Ayah entity and adds serialization methods
class AyahModel extends Ayah {
  const AyahModel({
    required super.id,
    required super.surahId,
    required super.ayahNumber,
    required super.textArabic,
    required super.textEnglish,
    super.textBengali = '',
  });

  /// Create AyahModel from JSON (API response)
  ///
  /// API returns three editions: Arabic (quran-uthmani), English (en.sahih),
  /// and Bengali (bn.bengali).
  ///
  /// [fallbackSurahId] is used when the nested `surah` object is missing
  /// from the ayah JSON (the caller always knows the surah ID).
  factory AyahModel.fromJson(
    Map<String, dynamic> arabicJson,
    Map<String, dynamic> englishJson, [
    Map<String, dynamic>? bengaliJson,
    int? fallbackSurahId,
  ]) {
    final surahData = arabicJson['surah'] as Map<String, dynamic>?;

    return AyahModel(
      id: (arabicJson['number'] as num?)?.toInt() ?? 0,
      surahId: (surahData?['number'] as num?)?.toInt() ??
          fallbackSurahId ??
          0,
      ayahNumber: (arabicJson['numberInSurah'] as num?)?.toInt() ?? 0,
      textArabic: (arabicJson['text'] as String?) ?? '',
      textEnglish: (englishJson['text'] as String?) ?? '',
      textBengali: (bengaliJson?['text'] as String?) ?? '',
    );
  }

  /// Create AyahModel from SQLite map
  factory AyahModel.fromMap(Map<String, dynamic> map) {
    return AyahModel(
      id: map['id'] as int,
      surahId: map['surah_id'] as int,
      ayahNumber: map['ayah_number'] as int,
      textArabic: map['text_arabic'] as String,
      textEnglish: map['text_english'] as String,
      textBengali: (map['text_bengali'] as String?) ?? '',
    );
  }

  /// Flat JSON map for Hive cache storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surah_id': surahId,
      'ayah_number': ayahNumber,
      'text_arabic': textArabic,
      'text_english': textEnglish,
      'text_bengali': textBengali,
    };
  }

  /// Create AyahModel from Hive cache map
  factory AyahModel.fromCacheJson(Map<String, dynamic> json) {
    return AyahModel(
      id: json['id'] as int,
      surahId: json['surah_id'] as int,
      ayahNumber: json['ayah_number'] as int,
      textArabic: json['text_arabic'] as String,
      textEnglish: json['text_english'] as String,
      textBengali: (json['text_bengali'] as String?) ?? '',
    );
  }

  /// Convert AyahModel to Ayah entity
  Ayah toEntity() {
    return Ayah(
      id: id,
      surahId: surahId,
      ayahNumber: ayahNumber,
      textArabic: textArabic,
      textEnglish: textEnglish,
      textBengali: textBengali,
    );
  }

  /// Create AyahModel from Ayah entity
  factory AyahModel.fromEntity(Ayah ayah) {
    return AyahModel(
      id: ayah.id,
      surahId: ayah.surahId,
      ayahNumber: ayah.ayahNumber,
      textArabic: ayah.textArabic,
      textEnglish: ayah.textEnglish,
      textBengali: ayah.textBengali,
    );
  }
}
