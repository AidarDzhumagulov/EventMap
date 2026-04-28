import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth_status_provider.dart';
import '../core/theme.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/event/screens/event_detail_screen.dart';
import '../features/event/screens/swipe_screen.dart';
import '../features/map/providers/events_provider.dart';
import '../features/map/screens/home_map_screen.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const homeMap = '/map';
  static const event = '/event';
  static const swipe = '/swipe';
}

// Мост между Riverpod и GoRouter для реактивного редиректа
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStatusProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authStatus = ref.read(authStatusProvider);
      final loc = state.matchedLocation;
      final onAuthPage = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.splash;

      if (authStatus == AuthStatus.unknown) return null;

      if (authStatus == AuthStatus.unauthenticated && !onAuthPage) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.homeMap,
        builder: (context, state) => const HomeMapScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.event}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return _EventLoadScreen(eventId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.swipe,
        builder: (context, state) => const SwipeScreen(),
      ),
    ],
    errorBuilder: (context, state) => const LoginScreen(),
  );
});

// Загружает событие по ID и показывает EventDetailScreen
class _EventLoadScreen extends ConsumerWidget {
  final String eventId;
  const _EventLoadScreen({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventByIdProvider(eventId));
    return eventAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: const Center(
          child: Text(
            'Событие не найдено',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (event) => EventDetailScreen(event: event),
    );
  }
}
