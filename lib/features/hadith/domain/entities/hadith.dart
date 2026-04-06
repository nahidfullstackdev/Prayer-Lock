/// A single Hadith entry
class Hadith {
  final String collection; // e.g. 'bukhari'
  final String bookNumber;
  final String hadithNumber;
  final String textArabic;
  final String textEnglish;
  final String chapterTitle; // English
  final String chapterTitleArabic;
  final String? gradeEn; // e.g. 'Sahih'
  final String? gradeAr; // e.g. 'صحيح'

  const Hadith({
    required this.collection,
    required this.bookNumber,
    required this.hadithNumber,
    required this.textArabic,
    required this.textEnglish,
    required this.chapterTitle,
    required this.chapterTitleArabic,
    this.gradeEn,
    this.gradeAr,
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
