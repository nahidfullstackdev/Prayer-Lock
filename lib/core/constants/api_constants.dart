/// API constants for the application
class ApiConstants {
  // Private constructor to prevent instantiation
  ApiConstants._();

  /// Al-Quran Cloud API base URL
  static const String quranApiBaseUrl = 'https://api.alquran.cloud/v1';

  // ── Hadith (fawazahmed0/hadith-api) ───────────────────────────────────────

  /// CDN base URL — free, no authentication required.
  /// Source: https://github.com/fawazahmed0/hadith-api
  static const String hadithApiBaseUrl =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1';

  /// All available editions (collections × languages) metadata.
  static const String hadithEditionsEndpoint = '/editions.min.json';

  /// Full edition endpoint — all hadiths for one book+language combination.
  /// [editionName] format: '{langCode}-{bookKey}' e.g. 'eng-bukhari', 'ara-muslim'
  static String hadithEditionEndpoint(String editionName) =>
      '/editions/$editionName.min.json';

  /// Default page size for free tier (local pagination from SQLite cache)
  static const int hadithFreePageSize = 10;

  /// Default page size for pro tier
  static const int hadithProPageSize = 20;

  // ── Quran ─────────────────────────────────────────────────────────────────

  /// Get all Surahs endpoint
  static const String getAllSurahsEndpoint = '/surah';

  /// Get specific Surah by ID with editions (Arabic + English + Bengali)
  /// Example: /surah/1/editions/quran-uthmani,en.sahih,bn.bengali
  static String getSurahByIdEndpoint(int surahId) {
    return '/surah/$surahId/editions/quran-uthmani,en.sahih,bn.bengali';
  }

  /// Get list of available editions
  static const String getEditionsEndpoint = '/edition';

  // ── Dua ───────────────────────────────────────────────────────────────────

  /// Dua data is bundled locally in assets/data/duas.json (offline-first).
  static const String duaAssetPath = 'assets/data/duas.json';

  // ── Timeouts ──────────────────────────────────────────────────────────────

  /// Connection timeout in milliseconds
  static const int connectionTimeout = 30000;

  /// Receive timeout in milliseconds — extended for large collection files (~2 MB each)
  static const int receiveTimeout = 60000;
}
