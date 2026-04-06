/// A Hadith collection (e.g. Sahih al-Bukhari)
class HadithCollection {
  final String name; // API slug, e.g. 'bukhari'
  final String title; // English title
  final String titleArabic; // Arabic title
  final int totalHadith;

  const HadithCollection({
    required this.name,
    required this.title,
    required this.titleArabic,
    required this.totalHadith,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HadithCollection &&
          other.name == name &&
          other.title == title &&
          other.titleArabic == titleArabic &&
          other.totalHadith == totalHadith;

  @override
  int get hashCode => Object.hash(name, title, titleArabic, totalHadith);

  @override
  String toString() =>
      'HadithCollection(name: $name, title: $title, totalHadith: $totalHadith)';
}
