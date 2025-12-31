import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

class DioClient {
  static final DioClient instance = DioClient._();
  final Dio _dio;
  final Logger _logger = Logger();

  DioClient._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.0.2.2:8000', // Use 10.0.2.2 for Android Emulator localhost
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.i('Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d('Response Code: ${response.statusCode}');
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          _logger.e('Error: ${e.message}', error: e.error, stackTrace: e.stackTrace);
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
