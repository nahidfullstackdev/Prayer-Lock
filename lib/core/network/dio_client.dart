import 'package:dio/dio.dart';
import 'package:prayer_lock/core/constants/api_constants.dart';
import 'package:prayer_lock/core/utils/logger.dart';

/// Configured Dio HTTP client for making API requests
class DioClient {
  // Singleton instance
  static final DioClient _instance = DioClient._internal();
  static DioClient get instance => _instance;

  late final Dio _dio;
  Dio get dio => _dio;

  // Private constructor
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.quranApiBaseUrl,
        connectTimeout: const Duration(milliseconds: ApiConstants.connectionTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConstants.receiveTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_LoggingInterceptor());
  }
}

/// Custom interceptor for logging API requests and responses
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug('API Request: ${options.method} ${options.uri}');
    if (options.data != null) {
      AppLogger.debug('Request Data: ${options.data}');
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.debug(
      'API Response: ${response.statusCode} ${response.requestOptions.uri}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      'API Error: ${err.requestOptions.uri}',
      err.message,
      err.stackTrace,
    );
    super.onError(err, handler);
  }
}
