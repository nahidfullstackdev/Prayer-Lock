/// API constants for the application
class ApiConstants {
  // Private constructor to prevent instantiation
  ApiConstants._();

  /// Al-Quran Cloud API base URL
  static const String quranApiBaseUrl = 'https://api.alquran.cloud/v1';

  /// Sunnah.com Hadith API base URL
  static const String hadithApiBaseUrl = 'https://api.sunnah.com/v1';

  /// Sunnah.com API key — set via: flutter run --dart-define=SUNNAH_API_KEY=your_key
  /// Get a free key at https://sunnah.com/developers
  static const String hadithApiKey = String.fromEnvironment(
    'SUNNAH_API_KEY',
    defaultValue: '',
  );

  /// Hadith collections endpoint
  static const String hadithCollectionsEndpoint = '/collections';

  /// Hadith list endpoint for a collection (paginated)
  static String hadithListEndpoint(String collection) =>
      '/collections/$collection/hadiths';

  /// Default page size for free tier
  static const int hadithFreePageSize = 10;

  /// Default page size for pro tier
  static const int hadithProPageSize = 20;

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
  /// Source: Hisnul Muslim (Fortress of the Muslim) by Sa'id bin Wahf Al-Qahtani.
  ///
  /// Future remote API candidate: https://api.hisnmuslim.com
  /// (no authentication required, community-maintained)
  static const String duaAssetPath = 'assets/data/duas.json';

  // ── Timeouts ──────────────────────────────────────────────────────────────

  /// Connection timeout in milliseconds
  static const int connectionTimeout = 30000;

  /// Receive timeout in milliseconds
  static const int receiveTimeout = 30000;
}
