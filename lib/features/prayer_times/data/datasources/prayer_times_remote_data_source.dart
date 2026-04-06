import 'package:dio/dio.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// Remote data source for fetching prayer times from Aladhan API
class PrayerTimesRemoteDataSource {
  final Dio dio;

  const PrayerTimesRemoteDataSource({required this.dio});

  /// Fetch prayer times from Aladhan API
  /// Endpoint: GET https://api.aladhan.com/v1/timings/{timestamp}
  /// Query params: latitude, longitude, method, school
  Future<Map<String, dynamic>> fetchPrayerTimes({
    required DateTime date,
    required double latitude,
    required double longitude,
    required int method,
    required int school, // 0: Shafi, 1: Hanafi
  }) async {
    try {
      final timestamp = date.millisecondsSinceEpoch ~/ 1000;

      AppLogger.info('Fetching prayer times from Aladhan API for $date');
      AppLogger.debug(
        'Parameters: lat=$latitude, lon=$longitude, method=$method, school=$school',
      );

      final response = await dio.get(
        'https://api.aladhan.com/v1/timings/$timestamp',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'method': method,
          'school': school,
        },
      );

      if (response.statusCode == 200) {
        AppLogger.info('Prayer times fetched successfully from API');
        return response.data as Map<String, dynamic>;
      } else {
        AppLogger.error(
          'Failed to fetch prayer times: ${response.statusCode}',
        );
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch prayer times: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      AppLogger.error('Dio error fetching prayer times', e);
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error fetching prayer times', e, stackTrace);
      throw DioException(
        requestOptions: RequestOptions(path: '/timings'),
        message: 'Unexpected error: $e',
      );
    }
  }
}
