import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final authStatusProvider = StateProvider<AuthStatus>(
  (ref) => AuthStatus.unknown,
);
