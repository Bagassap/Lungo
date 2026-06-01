import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  static String get _baseUrl => ApiConstants.baseUrl;

  static String get wsBaseUrl => _baseUrl;

  static Dio create() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(_AuthInterceptor(dio));
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint('[HTTP] $o'),
      ));
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
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final token = await SecureStorage.getAccessToken();
        err.requestOptions.headers['Authorization'] = 'Bearer $token';
        final retryResp = await dio.fetch(err.requestOptions);
        return handler.resolve(retryResp);
      }
      await SecureStorage.clear();
    }
    handler.next(err);
  }

  Future<bool> _tryRefresh() async {
    try {
      final userId = await SecureStorage.getUserId();
      final refreshToken = await SecureStorage.getRefreshToken();
      if (userId == null || refreshToken == null) return false;

      final resp = await Dio().post(
        '${ApiClient._baseUrl}/auth/refresh',
        data: {'userId': userId, 'refreshToken': refreshToken},
      );
      final newToken = resp.data['accessToken'] as String?;
      if (newToken == null) return false;
      await SecureStorage.saveAccessToken(newToken);
      return true;
    } catch (_) {
      return false;
    }
  }
}
