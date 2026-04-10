/// A Hadith collection (e.g. Sahih al-Bukhari).
class HadithCollection {
  /// API book key, e.g. 'bukhari', 'muslim'
  final String name;

  /// English title
  final String title;

  /// Arabic title
  final String titleArabic;

  final int totalHadith;

  /// Language codes available for this collection from the API.
  /// Subset of [HadithLanguage.allLanguages] codes, e.g. ['ara', 'eng', 'ben']
  final List<String> availableLanguages;

  const HadithCollection({
    required this.name,
    required this.title,
    required this.titleArabic,
    required this.totalHadith,
    this.availableLanguages = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HadithCollection && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() =>
      'HadithCollection(name: $name, title: $title, totalHadith: $totalHadith)';
}
