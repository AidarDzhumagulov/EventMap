import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/auth_status_provider.dart';
import 'core/theme.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);

  // Прозрачный статус-бар — UI выглядит на весь экран
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Только портретная ориентация для MVP
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    // ProviderScope — корень Riverpod, оборачивает всё приложение
    const ProviderScope(
      child: EventMapApp(),
    ),
  );
}

class EventMapApp extends ConsumerStatefulWidget {
  const EventMapApp({super.key});

  @override
  ConsumerState<EventMapApp> createState() => _EventMapAppState();
}

class _EventMapAppState extends ConsumerState<EventMapApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  // Глобальный ключ — позволяет показывать SnackBar из любого места,
  // включая dio interceptor (где BuildContext недоступен).
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // Ссылка, по которой открылось приложение (cold start)
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleLink(initial));
    }
    // Ссылки пока приложение работает (warm start)
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
  }

  void _handleLink(Uri uri) {
    if (uri.scheme != 'eventmap') return;
    final router = ref.read(appRouterProvider);

    switch (uri.host) {
      // eventmap://event/{id}
      case 'event':
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (id != null && id.isNotEmpty) {
          router.go('/event/$id');
        }
      // eventmap://reset-password?token=...
      case 'reset-password':
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          router.go('/reset-password?token=$token');
        }
      // eventmap://verify-email?token=...
      case 'verify-email':
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          router.go('/verify-email?token=$token');
        }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Слушаем причину принудительного logout (например, при token reuse).
    // Показываем юзеру SnackBar и сбрасываем состояние.
    ref.listen<String?>(forcedLogoutReasonProvider, (_, reason) {
      if (reason == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(reason),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
        ref.read(forcedLogoutReasonProvider.notifier).state = null;
      });
    });

    return MaterialApp.router(
      title: 'Event Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
