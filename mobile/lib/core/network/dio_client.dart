import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth_status_provider.dart';

// В продакшене передаётся через --dart-define=API_BASE_URL=https://api.example.com
// В dev-режиме: Android эмулятор = 10.0.2.2, iOS симулятор = localhost
const _prodBaseUrl = String.fromEnvironment('API_BASE_URL');

String get baseUrl {
  if (_prodBaseUrl.isNotEmpty) return _prodBaseUrl;
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://localhost:8080';
}

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
        if (error.response?.statusCode == 401) {
          final refreshToken = await storage.read(key: _refreshTokenKey);
          if (refreshToken != null) {
            try {
              final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
              final response = await refreshDio.post(
                '/refresh',
                options: Options(
                  headers: {'Authorization': 'Bearer $refreshToken'},
                ),
              );
              final newAccess = response.data['access_token'] as String;
              final newRefresh = response.data['refresh_token'] as String;
              await saveTokens(storage,
                  accessToken: newAccess, refreshToken: newRefresh);

              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newAccess';
              final retryResponse = await dio.fetch(opts);
              return handler.resolve(retryResponse);
            } catch (_) {}
          }
          // refresh-токена нет или refresh тоже вернул 401 — выбрасываем на логин
          await storage.deleteAll();
          ref.read(authStatusProvider.notifier).state =
              AuthStatus.unauthenticated;
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
