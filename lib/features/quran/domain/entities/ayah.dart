/// Ayah entity representing a verse of the Quran
///
/// Immutable business object with no dependencies
class Ayah {
  /// Unique identifier for the Ayah
  final int id;

  /// ID of the Surah this Ayah belongs to (1-114)
  final int surahId;

  /// Ayah number within the Surah
  final int ayahNumber;

  /// Arabic text of the Ayah
  final String textArabic;

  /// English translation of the Ayah
  final String textEnglish;

  /// Bengali translation of the Ayah
  final String textBengali;

  const Ayah({
    required this.id,
    required this.surahId,
    required this.ayahNumber,
    required this.textArabic,
    required this.textEnglish,
    this.textBengali = '',
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Ayah &&
        other.id == id &&
        other.surahId == surahId &&
        other.ayahNumber == ayahNumber &&
        other.textArabic == textArabic &&
        other.textEnglish == textEnglish &&
        other.textBengali == textBengali;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      surahId,
      ayahNumber,
      textArabic,
      textEnglish,
      textBengali,
    );
  }

  @override
  String toString() {
    return 'Ayah(id: $id, surahId: $surahId, ayahNumber: $ayahNumber)';
  }
}
