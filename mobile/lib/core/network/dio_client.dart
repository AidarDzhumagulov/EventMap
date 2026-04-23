import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// На Android эмуляторе localhost = 10.0.2.2
// На iOS симуляторе = localhost
const _androidBaseUrl = 'http://10.0.2.2:8080';
const _iosBaseUrl = 'http://localhost:8080';

String get baseUrl =>
    defaultTargetPlatform == TargetPlatform.android
        ? _androidBaseUrl
        : _iosBaseUrl;

const _accessTokenKey = 'access_token';
const _refreshTokenKey = 'refresh_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final dioClientProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Interceptor — автоматически добавляет JWT к каждому запросу
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: _accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // 401 — токен истёк, пробуем refresh
        if (error.response?.statusCode == 401) {
          final refreshToken = await storage.read(key: _refreshTokenKey);
          if (refreshToken != null) {
            // TODO: вызов /refresh endpoint когда он будет на бэке
            await storage.deleteAll();
          }
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
});

// Хелперы для работы с токенами
Future<void> saveTokens(
  FlutterSecureStorage storage, {
  required String accessToken,
  required String refreshToken,
}) async {
  await storage.write(key: _accessTokenKey, value: accessToken);
  await storage.write(key: _refreshTokenKey, value: refreshToken);
}

Future<void> clearTokens(FlutterSecureStorage storage) async {
  await storage.deleteAll();
}

Future<bool> hasToken(FlutterSecureStorage storage) async {
  final token = await storage.read(key: _accessTokenKey);
  return token != null;
}
