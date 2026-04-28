import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

/// Единая точка показа SnackBar'ов — никаких локальных копипастов.
///
/// Использование:
/// ```dart
/// context.showError('Не удалось загрузить');
/// context.showSuccess('Сохранено!');
/// context.showApiError(e); // авто-маппинг DioException → читаемый текст
/// ```
extension SnackbarX on BuildContext {
  void showError(String message) => _show(this, message, AppColors.error);

  void showSuccess(String message) => _show(this, message, AppColors.success);

  void showInfo(String message) => _show(this, message, AppColors.primary);

  /// Маппит DioException на человекочитаемое сообщение по статус-коду.
  void showApiError(Object e, {String fallback = 'Что-то пошло не так'}) {
    final msg = _humanize(e, fallback);
    _show(this, msg, AppColors.error);
  }
}

void _show(BuildContext context, String message, Color color) {
  // Защита от показа на уже размонтированном контексте.
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

String _humanize(Object e, String fallback) {
  if (e is DioException) {
    switch (e.response?.statusCode) {
      case 400:
        return 'Неверные данные';
      case 401:
        return 'Нужно войти заново';
      case 403:
        return 'Нет прав на это действие';
      case 404:
        return 'Не найдено';
      case 409:
        return 'Конфликт данных';
      case 429:
        return 'Слишком много запросов, подождите';
      case 500:
      case 502:
      case 503:
        return 'Сервер не отвечает';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'Нет связи с сервером';
    }
  }
  return fallback;
}
