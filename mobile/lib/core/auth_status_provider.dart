import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final authStatusProvider = StateProvider<AuthStatus>(
  (ref) => AuthStatus.unknown,
);

/// Причина принудительного logout — показывается юзеру SnackBar'ом
/// при следующем фрейме. После показа сбрасывается в null.
///
/// Установка в interceptor (`dio_client.dart`) при `X-Auth-Error: token_reuse`,
/// слушается в `EventMapApp` для показа уведомления.
final forcedLogoutReasonProvider = StateProvider<String?>((ref) => null);
