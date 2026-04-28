import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth_status_provider.dart';
import '../repository/auth_repository.dart';

// Состояние авторизации
sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthSuccess extends AuthState {}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthInitial();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = AuthLoading();
    try {
      await _repo.login(email: email, password: password);
      ref.read(authStatusProvider.notifier).state = AuthStatus.authenticated;
      state = AuthSuccess();
      return true;
    } on AuthException catch (e) {
      state = AuthError(e.message);
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = AuthLoading();
    try {
      await _repo.register(
          username: username, email: email, password: password);
      // После регистрации — сразу логиним
      await _repo.login(email: email, password: password);
      ref.read(authStatusProvider.notifier).state = AuthStatus.authenticated;
      state = AuthSuccess();
      return true;
    } on AuthException catch (e) {
      state = AuthError(e.message);
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    ref.read(authStatusProvider.notifier).state = AuthStatus.unauthenticated;
    state = AuthInitial();
  }

  /// Logout со всех устройств — отзывает все refresh-сессии на сервере.
  Future<void> logoutAll() async {
    await _repo.logoutAll();
    ref.read(authStatusProvider.notifier).state = AuthStatus.unauthenticated;
    state = AuthInitial();
  }

  void clearError() {
    state = AuthInitial();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// Используется в роутере для редиректа
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  return repo.isLoggedIn();
});
