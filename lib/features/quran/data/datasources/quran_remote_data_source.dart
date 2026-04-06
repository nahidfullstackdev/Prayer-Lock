import 'package:dio/dio.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/quran/data/models/ayah_model.dart';
import 'package:prayer_lock/features/quran/data/models/surah_model.dart';

/// Remote data source for fetching Quran data from API
class QuranRemoteDataSource {
  final Dio dio;

  const QuranRemoteDataSource({required this.dio});

  /// Fetch all Surahs from API
  ///
  /// Throws [DioException] on network errors
  Future<List<SurahModel>> fetchAllSurahs() async {
    try {
      AppLogger.info('Fetching all Surahs from API');

      final response = await dio.get(ApiConstants.getAllSurahsEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final surahsJson = data['data'] as List<dynamic>;

        final surahs = surahsJson
            .map((json) => SurahModel.fromJson(json as Map<String, dynamic>))
            .toList();

        AppLogger.info('Fetched ${surahs.length} Surahs from API');
        return surahs;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch Surahs: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching Surahs', e, stackTrace);
      throw DioException(
        requestOptions: RequestOptions(
          path: ApiConstants.getAllSurahsEndpoint,
        ),
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Fetch Surah by ID with Ayahs (Arabic + English + Bengali translations)
  ///
  /// [surahId] - The Surah number (1-114)
  ///
  /// Throws [DioException] on network errors
  Future<List<AyahModel>> fetchSurahById(int surahId) async {
    try {
      AppLogger.info('Fetching Surah $surahId from API');

      final response = await dio.get(
        ApiConstants.getSurahByIdEndpoint(surahId),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>?;
        final editions = data?['data'] as List<dynamic>?;

        if (editions == null || editions.length < 2) {
          throw DioException(
            requestOptions: response.requestOptions,
            message:
                'API response missing editions (got ${editions?.length ?? 0})',
          );
        }

        // editions[0] is Arabic (quran-uthmani)
        // editions[1] is English (en.sahih)
        // editions[2] is Bengali (bn.bengali) — optional
        final arabicEdition = editions[0] as Map<String, dynamic>?;
        final englishEdition = editions[1] as Map<String, dynamic>?;
        final bengaliEdition = editions.length > 2
            ? editions[2] as Map<String, dynamic>?
            : null;

        final arabicAyahs = arabicEdition?['ayahs'] as List<dynamic>?;
        final englishAyahs = englishEdition?['ayahs'] as List<dynamic>?;
        final bengaliAyahs = bengaliEdition?['ayahs'] as List<dynamic>?;

        if (arabicAyahs == null || englishAyahs == null) {
          throw DioException(
            requestOptions: response.requestOptions,
            message: 'Arabic or English ayahs missing from API response',
          );
        }

        if (arabicAyahs.length != englishAyahs.length) {
          throw DioException(
            requestOptions: response.requestOptions,
            message: 'Ayah counts mismatch across editions',
          );
        }

        final ayahs = <AyahModel>[];
        for (var i = 0; i < arabicAyahs.length; i++) {
          ayahs.add(
            AyahModel.fromJson(
              arabicAyahs[i] as Map<String, dynamic>,
              englishAyahs[i] as Map<String, dynamic>,
              bengaliAyahs != null && i < bengaliAyahs.length
                  ? bengaliAyahs[i] as Map<String, dynamic>
                  : null,
              surahId,
            ),
          );
        }

        AppLogger.info('Fetched ${ayahs.length} Ayahs for Surah $surahId');
        return ayahs;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch Surah $surahId: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error fetching Surah $surahId',
        e,
        stackTrace,
      );
      throw DioException(
        requestOptions: RequestOptions(
          path: ApiConstants.getSurahByIdEndpoint(surahId),
        ),
        message: 'Unexpected error: $e',
      );
    }
  }
}
