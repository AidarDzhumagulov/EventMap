import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

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
    // eventmap://event/{id}
    if (uri.scheme == 'eventmap' && uri.host == 'event') {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (id != null && id.isNotEmpty) {
        ref.read(appRouterProvider).go('/event/$id');
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
    return MaterialApp.router(
      title: 'Event Map',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
