import 'package:dio/dio.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_collection_model.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_model.dart';

/// Fetches Hadith data from the fawazahmed0/hadith-api CDN.
///
/// Free, open, no authentication required.
/// Source: https://github.com/fawazahmed0/hadith-api
class HadithRemoteDataSource {
  final Dio dio;

  const HadithRemoteDataSource({required this.dio});

  // Supported book keys — order controls display on collections screen
  static const List<String> _supportedBooks = [
    'bukhari',
    'muslim',
    'tirmidhi',
    'abudawud',
    'nasai',
    'ibnmajah',
    'malik',
    'nawawi',
    'qudsi',
    'dehlawi',
  ];

  /// GET /editions.min.json
  ///
  /// Returns all 10 supported collections with their available languages parsed
  /// from the CDN metadata.
  Future<List<HadithCollectionModel>> fetchEditions() async {
    try {
      AppLogger.info('Fetching hadith editions metadata from CDN');
      final response = await dio.get(ApiConstants.hadithEditionsEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final models = <HadithCollectionModel>[];

        for (final bookKey in _supportedBooks) {
          if (data.containsKey(bookKey)) {
            models.add(
              HadithCollectionModel.fromEditionsJson(
                bookKey,
                data[bookKey] as Map<String, dynamic>,
              ),
            );
          }
        }

        AppLogger.info('Fetched metadata for ${models.length} collections');
        return models;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch editions: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Unexpected error fetching hadith editions', e, st);
      throw DioException(
        requestOptions:
            RequestOptions(path: ApiConstants.hadithEditionsEndpoint),
        message: 'Unexpected error: $e',
      );
    }
  }

  /// GET /editions/{langCode}-{bookKey}.min.json
  ///
  /// Fetches ALL hadiths for one language edition of a book.
  /// Each returned [HadithModel] has a single-key [translations] map:
  /// `{ langCode: text }`. The repository merges multiple editions.
  Future<List<HadithModel>> fetchHadithsForEdition({
    required String bookKey,   // e.g. 'bukhari'
    required String langCode,  // e.g. 'eng', 'ara'
  }) async {
    final editionName = '$langCode-$bookKey';
    final endpoint = ApiConstants.hadithEditionEndpoint(editionName);

    try {
      AppLogger.info('Fetching edition $editionName from CDN');
      final response = await dio.get(endpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final metadata = (data['metadata'] as Map<String, dynamic>?) ?? {};
        final hadithsList = (data['hadiths'] as List<dynamic>?) ?? [];

        final sectionLookup = _buildSectionLookup(metadata);

        final models = hadithsList
            .map(
              (e) => HadithModel.fromApiJson(
                e as Map<String, dynamic>,
                bookKey,
                langCode,
                sectionLookup,
              ),
            )
            .toList();

        AppLogger.info('Fetched ${models.length} hadiths for $editionName');
        return models;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch $editionName: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error fetching edition $editionName',
        e,
        st,
      );
      throw DioException(
        requestOptions: RequestOptions(path: endpoint),
        message: 'Unexpected error: $e',
      );
    }
  }

  /// Builds a [hadithNumber] → [sectionName] lookup from edition metadata.
  ///
  /// The metadata contains:
  ///   section: { "1": "Revelation", "2": "Belief", ... }
  ///   section_detail: { "1": { "hadithnumber_first": 1, "hadithnumber_last": 7 }, ... }
  Map<int, String> _buildSectionLookup(Map<String, dynamic> metadata) {
    final sectionNames =
        (metadata['section'] as Map<String, dynamic>?) ?? {};
    final sectionDetails =
        (metadata['section_detail'] as Map<String, dynamic>?) ?? {};

    final lookup = <int, String>{};
    for (final entry in sectionDetails.entries) {
      final detail = (entry.value as Map<String, dynamic>?) ?? {};
      final first = (detail['hadithnumber_first'] as num?)?.toInt() ?? 0;
      final last = (detail['hadithnumber_last'] as num?)?.toInt() ?? 0;
      final sectionName = sectionNames[entry.key]?.toString() ?? '';
      for (var n = first; n <= last; n++) {
        lookup[n] = sectionName;
      }
    }
    return lookup;
  }
}
