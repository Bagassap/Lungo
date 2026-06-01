import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static Dio create() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    dio.interceptors.add(_AuthInterceptor(dio));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false,
            logPrint: (o) => debugPrint('[HTTP] $o')),
      );
    }
    return dio;
  }
}

class _AuthInterceptor extends Interceptor {
  final Dio dio;
  _AuthInterceptor(this.dio);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final userId = await SecureStorage.getUserId();
        final refreshToken = await SecureStorage.getRefreshToken();
        if (userId != null && refreshToken != null) {
          final resp = await Dio().post(
            '${ApiConstants.baseUrl}/auth/refresh',
            data: {'userId': userId, 'refreshToken': refreshToken},
          );
          final newToken = resp.data['accessToken'] as String?;
          if (newToken != null) {
            await SecureStorage.saveAccessToken(newToken);
            err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            return handler.resolve(await dio.fetch(err.requestOptions));
          }
        }
      } catch (_) {}
      // Do NOT clear SecureStorage here — this client is used by background
      // services (e.g. FCM token upload) that should not invalidate the
      // user's auth session on failure.
    }
    handler.next(err);
  }
}
