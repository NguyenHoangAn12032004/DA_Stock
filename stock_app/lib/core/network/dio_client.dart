import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DioClient {
  static final DioClient instance = DioClient._();
  final Dio _dio;
  final Logger _logger = Logger();

  DioClient._()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'http://10.0.2.2:8000', // Use 10.0.2.2 for Android Emulator localhost
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.i('Request: ${options.method} ${options.path}');
          // Inject User ID for "Online Users" tracking
          try {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              options.headers["x-user-id"] = user.uid;
            }
          } catch (e) {
            // Ignore auth errors in networking
          }
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
