import 'package:prayer_lock/features/hadith/domain/entities/hadith.dart';

/// Data model for a Hadith — handles JSON parsing and SQLite mapping.
class HadithModel extends Hadith {
  const HadithModel({
    required super.collection,
    required super.bookNumber,
    required super.hadithNumber,
    required super.textArabic,
    required super.textEnglish,
    required super.chapterTitle,
    required super.chapterTitleArabic,
    super.gradeEn,
    super.gradeAr,
  });

  // ── API (sunnah.com) ─────────────────────────────────────────────────────

  /// Parses one item from GET /collections/{name}/hadiths response data array.
  factory HadithModel.fromJson(Map<String, dynamic> json) {
    final langs = (json['hadith'] as List<dynamic>?) ?? [];

    String arBody = '';
    String enBody = '';
    String arChapter = '';
    String enChapter = '';
    String? gradeEn;
    String? gradeAr;

    for (final lang in langs) {
      final map = lang as Map<String, dynamic>;
      final langCode = map['lang'] as String? ?? '';

      if (langCode == 'ar') {
        arBody = (map['body'] as String?) ?? '';
        arChapter = (map['chapterTitle'] as String?) ?? '';
        final grades = map['grades'] as List<dynamic>?;
        if (grades != null && grades.isNotEmpty) {
          gradeAr = (grades.first as Map<String, dynamic>)['grade'] as String?;
        }
      } else if (langCode == 'en') {
        enBody = (map['body'] as String?) ?? '';
        enChapter = (map['chapterTitle'] as String?) ?? '';
        final grades = map['grades'] as List<dynamic>?;
        if (grades != null && grades.isNotEmpty) {
          gradeEn = (grades.first as Map<String, dynamic>)['grade'] as String?;
        }
      }
    }

    return HadithModel(
      collection: (json['collection'] as String?) ?? '',
      bookNumber: (json['bookNumber'] as String?) ?? '',
      hadithNumber: (json['hadithNumber'] as String?) ?? '',
      textArabic: arBody,
      textEnglish: enBody,
      chapterTitle: enChapter,
      chapterTitleArabic: arChapter,
      gradeEn: gradeEn,
      gradeAr: gradeAr,
    );
  }

  // ── SQLite ────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap({required int page}) => {
        'collection': collection,
        'book_number': bookNumber,
        'hadith_number': hadithNumber,
        'text_arabic': textArabic,
        'text_english': textEnglish,
        'chapter_title': chapterTitle,
        'chapter_title_arabic': chapterTitleArabic,
        'grade_en': gradeEn,
        'grade_ar': gradeAr,
        'page': page,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory HadithModel.fromMap(Map<String, dynamic> map) => HadithModel(
        collection: map['collection'] as String,
        bookNumber: map['book_number'] as String,
        hadithNumber: map['hadith_number'] as String,
        textArabic: map['text_arabic'] as String,
        textEnglish: map['text_english'] as String,
        chapterTitle: map['chapter_title'] as String,
        chapterTitleArabic: map['chapter_title_arabic'] as String,
        gradeEn: map['grade_en'] as String?,
        gradeAr: map['grade_ar'] as String?,
      );

  Hadith toEntity() => Hadith(
        collection: collection,
        bookNumber: bookNumber,
        hadithNumber: hadithNumber,
        textArabic: textArabic,
        textEnglish: textEnglish,
        chapterTitle: chapterTitle,
        chapterTitleArabic: chapterTitleArabic,
        gradeEn: gradeEn,
        gradeAr: gradeAr,
      );
}
