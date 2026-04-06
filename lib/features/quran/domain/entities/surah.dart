/// Surah entity representing a chapter of the Quran
///
/// Immutable business object with no dependencies
class Surah {
  /// Surah number (1-114)
  final int id;

  /// Arabic name of the Surah
  final String nameArabic;

  /// Transliteration of the Surah name (e.g., "Al-Fatihah")
  final String nameTransliteration;

  /// English name/translation of the Surah
  final String nameEnglish;

  /// Revelation place: "Meccan" or "Medinan"
  final String revelationPlace;

  /// Total number of Ayahs in this Surah
  final int totalAyahs;

  const Surah({
    required this.id,
    required this.nameArabic,
    required this.nameTransliteration,
    required this.nameEnglish,
    required this.revelationPlace,
    required this.totalAyahs,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Surah &&
        other.id == id &&
        other.nameArabic == nameArabic &&
        other.nameTransliteration == nameTransliteration &&
        other.nameEnglish == nameEnglish &&
        other.revelationPlace == revelationPlace &&
        other.totalAyahs == totalAyahs;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      nameArabic,
      nameTransliteration,
      nameEnglish,
      revelationPlace,
      totalAyahs,
    );
  }

  @override
  String toString() {
    return 'Surah(id: $id, nameArabic: $nameArabic, nameTransliteration: $nameTransliteration, nameEnglish: $nameEnglish, revelationPlace: $revelationPlace, totalAyahs: $totalAyahs)';
  }
}
