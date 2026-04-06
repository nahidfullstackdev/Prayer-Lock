import 'package:dio/dio.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_collection_model.dart';
import 'package:prayer_lock/features/hadith/data/models/hadith_model.dart';

/// Fetches Hadith data from the sunnah.com API (v1).
///
/// All endpoints require the X-API-Key header configured in [Dio].
class HadithRemoteDataSource {
  final Dio dio;

  const HadithRemoteDataSource({required this.dio});

  /// GET /collections — returns the 6 major collections.
  ///
  /// Filters to only the collections used by this app.
  Future<List<HadithCollectionModel>> fetchCollections() async {
    const allowedCollections = {
      'bukhari',
      'muslim',
      'tirmidhi',
      'abudawud',
      'nasai',
      'ibnmajah',
    };

    try {
      AppLogger.info('Fetching Hadith collections from API');
      final response = await dio.get(ApiConstants.hadithCollectionsEndpoint);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List<dynamic>?) ?? [];

        final models = list
            .map(
              (e) => HadithCollectionModel.fromJson(e as Map<String, dynamic>),
            )
            .where((c) => allowedCollections.contains(c.name))
            .toList();

        // Preserve insertion order matching allowedCollections ordering.
        final ordered = allowedCollections.toList();
        models.sort(
          (a, b) => ordered.indexOf(a.name) - ordered.indexOf(b.name),
        );

        AppLogger.info('Fetched ${models.length} Hadith collections');
        return models;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch collections: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Unexpected error fetching Hadith collections', e, st);
      throw DioException(
        requestOptions:
            RequestOptions(path: ApiConstants.hadithCollectionsEndpoint),
        message: 'Unexpected error: $e',
      );
    }
  }

  /// GET /collections/{collection}/hadiths?limit=N&page=N
  Future<List<HadithModel>> fetchHadiths({
    required String collection,
    required int page,
    required int limit,
  }) async {
    final path = ApiConstants.hadithListEndpoint(collection);
    try {
      AppLogger.info(
        'Fetching Hadiths for $collection page=$page limit=$limit',
      );
      final response = await dio.get(
        path,
        queryParameters: {'limit': limit, 'page': page},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final list = (data['data'] as List<dynamic>?) ?? [];
        final models = list
            .map((e) => HadithModel.fromJson(e as Map<String, dynamic>))
            .toList();
        AppLogger.info('Fetched ${models.length} hadiths from $collection');
        return models;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch hadiths: ${response.statusCode}',
        );
      }
    } on DioException {
      rethrow;
    } catch (e, st) {
      AppLogger.error('Unexpected error fetching hadiths', e, st);
      throw DioException(
        requestOptions: RequestOptions(path: path),
        message: 'Unexpected error: $e',
      );
    }
  }
}
