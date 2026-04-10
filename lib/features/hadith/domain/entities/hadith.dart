/// A single Hadith entry with multi-language support.
class Hadith {
  /// Book key, e.g. 'bukhari', 'muslim'
  final String collection;

  /// Primary hadith number (used for ordering and caching)
  final int hadithNumber;

  /// Arabic numbering (may differ from hadithNumber in some editions)
  final int arabicNumber;

  /// Chapter / section title (sourced from the English edition)
  final String section;

  /// Language code → translated text.
  /// Keys match [HadithLanguage.code]: 'ara', 'eng', 'ben', etc.
  final Map<String, String> translations;

  /// Authenticity grade, e.g. 'Sahih', 'Hasan', 'Da\'if' (null if ungraded)
  final String? grade;

  const Hadith({
    required this.collection,
    required this.hadithNumber,
    required this.arabicNumber,
    required this.section,
    required this.translations,
    this.grade,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hadith &&
          other.collection == collection &&
          other.hadithNumber == hadithNumber;

  @override
  int get hashCode => Object.hash(collection, hadithNumber);

  @override
  String toString() =>
      'Hadith(collection: $collection, hadithNumber: $hadithNumber)';
}
