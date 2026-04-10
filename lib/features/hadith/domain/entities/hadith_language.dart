/// Represents a display language supported by the fawazahmed0/hadith-api.
class HadithLanguage {
  final String code;  // e.g. 'ara', 'eng', 'ben'
  final String name;  // e.g. 'Arabic', 'English', 'Bengali'
  final bool isRtl;   // true for Arabic and Urdu

  const HadithLanguage({
    required this.code,
    required this.name,
    required this.isRtl,
  });

  /// All languages available across the hadith-api CDN editions.
  static const List<HadithLanguage> allLanguages = [
    HadithLanguage(code: 'ara', name: 'Arabic', isRtl: true),
    HadithLanguage(code: 'eng', name: 'English', isRtl: false),
    HadithLanguage(code: 'ben', name: 'Bengali', isRtl: false),
    HadithLanguage(code: 'fra', name: 'French', isRtl: false),
    HadithLanguage(code: 'ind', name: 'Indonesian', isRtl: false),
    HadithLanguage(code: 'rus', name: 'Russian', isRtl: false),
    HadithLanguage(code: 'tam', name: 'Tamil', isRtl: false),
    HadithLanguage(code: 'tur', name: 'Turkish', isRtl: false),
    HadithLanguage(code: 'urd', name: 'Urdu', isRtl: true),
  ];

  /// Default language codes shown in hadith cards out of the box.
  static const List<String> defaultSelected = ['ara', 'eng'];

  /// Returns the [HadithLanguage] for [code], or null if not found.
  static HadithLanguage? fromCode(String code) {
    try {
      return allLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'HadithLanguage($code: $name)';
}
