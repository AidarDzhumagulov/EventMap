import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/dio_client.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  const AuthRepository(this._dio, this._storage);

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );
      final tokens = AuthTokens.fromJson(response.data);
      await saveTokens(_storage,
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken);
      return tokens;
    } on DioException catch (e) {
      throw AuthException(_parseDioError(e));
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post(
        '/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'role': 'user',
        },
      );
    } on DioException catch (e) {
      throw AuthException(_parseDioError(e));
    }
  }

  Future<void> logout() async {
    await clearTokens(_storage);
  }

  Future<bool> isLoggedIn() async {
    return hasToken(_storage);
  }

  String _parseDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Нет соединения с сервером';
    }

    final statusCode = e.response?.statusCode;
    final body = e.response?.data;

    if (statusCode == 401) return 'Неверный email или пароль';
    if (statusCode == 400) {
      if (body is String && body.contains('Email already exist')) {
        return 'Email уже зарегистрирован';
      }
      if (body is String && body.contains('Username already exist')) {
        return 'Имя пользователя уже занято';
      }
      return 'Неверные данные';
    }
    if (statusCode == 500) return 'Ошибка сервера, попробуй позже';

    return 'Что-то пошло не так';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(dioClientProvider),
    ref.read(secureStorageProvider),
  );
});
