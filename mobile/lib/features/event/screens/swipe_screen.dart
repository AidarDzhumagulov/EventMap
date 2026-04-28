import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../map/providers/events_provider.dart';
import '../../map/repository/event_repository.dart';
import 'event_detail_screen.dart';

// ─── Notifier ──────────────────────────────────────────────────────────────

class SwipeNotifier
    extends AutoDisposeNotifier<AsyncValue<List<EventModel>>> {
  @override
  AsyncValue<List<EventModel>> build() {
    _load();
    return const AsyncValue.loading();
  }

  Future<void> _load() async {
    try {
      final city = ref.read(selectedCityProvider);
      final events =
          await ref.read(eventRepositoryProvider).getFeed(city: city);
      state = AsyncValue.data(events);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  EventModel? _topCard() {
    EventModel? event;
    state.whenData((list) {
      if (list.isNotEmpty) event = list.first;
    });
    return event;
  }

  void _popTop() {
    state.whenData((list) {
      if (list.isNotEmpty) state = AsyncValue.data(list.sublist(1));
    });
  }

  Future<void> skip() async {
    final event = _topCard();
    if (event == null) return;
    _popTop();
    try {
      await ref.read(eventRepositoryProvider).markSkipped(event.id);
    } catch (_) {
      // Сетевая ошибка — UX не блокируем, событие всё равно ушло из стопки.
      // На бэке оно потом снова появится, но это лучше чем зависший экран.
    }
  }

  Future<void> save() async {
    final event = _topCard();
    if (event == null) return;
    _popTop();
    try {
      await ref.read(dioClientProvider).post(
        '/events/save',
        queryParameters: {'id': event.id},
      );
    } catch (_) {}
  }

  void reload() {
    state = const AsyncValue.loading();
    _load();
  }
}

final swipeProvider = AutoDisposeNotifierProvider<SwipeNotifier,
    AsyncValue<List<EventModel>>>(SwipeNotifier.new);

// ─── Screen ────────────────────────────────────────────────────────────────

class SwipeScreen extends ConsumerStatefulWidget {
  const SwipeScreen({super.key});

  @override
  ConsumerState<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends ConsumerState<SwipeScreen>
    with TickerProviderStateMixin {
  // Current visual position of the top card
  Offset _offset = Offset.zero;
  double _rotation = 0.0;
  bool _throwing = false;
  bool _throwRight = false;

  // Throw animation (card flies offscreen)
  late final AnimationController _throwCtrl;
  Offset _throwStart = Offset.zero;
  Offset _throwEnd = Offset.zero;

  // Snap-back animation (card returns to center)
  late final AnimationController _snapCtrl;
  Offset _snapStart = Offset.zero;
  double _snapStartRotation = 0.0;

  @override
  void initState() {
    super.initState();

    _throwCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )
      ..addListener(_onThrowTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finishThrow();
      });

    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )
      ..addListener(_onSnapTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _snapCtrl.reset();
      });
  }

  void _onThrowTick() {
    final t = Curves.easeIn.transform(_throwCtrl.value);
    setState(() {
      _offset = Offset.lerp(_throwStart, _throwEnd, t)!;
      _rotation = lerpDouble(
        _throwRight ? 0.12 : -0.12,
        _throwRight ? 0.38 : -0.38,
        t,
      )!;
    });
  }

  void _onSnapTick() {
    final t = _snapCtrl.value;
    setState(() {
      _offset = Offset.lerp(
        _snapStart,
        Offset.zero,
        Curves.elasticOut.transform(t),
      )!;
      _rotation =
          lerpDouble(_snapStartRotation, 0, Curves.easeOut.transform(t))!;
    });
  }

  void _finishThrow() {
    _throwCtrl.reset();
    _throwing = false;
    setState(() {
      _offset = Offset.zero;
      _rotation = 0;
    });
    if (_throwRight) {
      ref.read(swipeProvider.notifier).save();
    } else {
      ref.read(swipeProvider.notifier).skip();
    }
  }

  void _throwCard(bool toRight) {
    if (_throwing || _snapCtrl.isAnimating) return;
    _throwing = true;
    _throwRight = toRight;
    _throwStart = _offset;
    _throwEnd = Offset(toRight ? 700 : -700, _offset.dy + 60);
    _throwCtrl.forward();
  }

  void _snapBack() {
    _snapStart = _offset;
    _snapStartRotation = _rotation;
    _snapCtrl.reset();
    _snapCtrl.forward();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_throwing || _snapCtrl.isAnimating) return;
    setState(() {
      _offset += Offset(d.delta.dx, d.delta.dy * 0.3);
      _rotation = _offset.dx * 0.0014;
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_throwing) return;
    if (_offset.dx.abs() > 100) {
      _throwCard(_offset.dx > 0);
    } else {
      _snapBack();
    }
  }

  @override
  void dispose() {
    _throwCtrl.dispose();
    _snapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardW = size.width - 32.0;
    final cardH = size.height * 0.63;
    final asyncState = ref.watch(swipeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Куда пойти?'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary),
            onPressed: () => ref.read(swipeProvider.notifier).reload(),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => _buildError(),
        data: (events) {
          if (events.isEmpty) return _buildEmpty();
          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Text(
                    '${events.length} событий рядом',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),

                // ── Card stack ──────────────────────────────────────────
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (events.length > 2)
                        _BackCard(
                          event: events[2],
                          width: cardW,
                          height: cardH,
                          scale: 0.87,
                          offsetY: -20,
                        ),
                      if (events.length > 1)
                        _BackCard(
                          event: events[1],
                          width: cardW,
                          height: cardH,
                          scale: 0.94,
                          offsetY: -10,
                        ),
                      // Top card — interactive
                      GestureDetector(
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: Transform.translate(
                          offset: _offset,
                          child: Transform.rotate(
                            angle: _rotation,
                            child: SizedBox(
                              width: cardW,
                              height: cardH,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _EventCard(event: events[0]),
                                  // ❤️ save hint
                                  _SwipeOverlay(
                                    label: '❤️  СОХРАНИТЬ',
                                    color: AppColors.primary,
                                    alignment: Alignment.topLeft,
                                    opacity: (_offset.dx / 110)
                                        .clamp(0.0, 1.0),
                                  ),
                                  // ✕ skip hint
                                  _SwipeOverlay(
                                    label: '✕  ПРОПУСТИТЬ',
                                    color: AppColors.error,
                                    alignment: Alignment.topRight,
                                    opacity: (-_offset.dx / 110)
                                        .clamp(0.0, 1.0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Action buttons ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionButton(
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        onTap: () => _throwCard(false),
                      ),
                      // Подробнее
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EventDetailScreen(event: events[0]),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.textHint, size: 22),
                            SizedBox(height: 3),
                            Text(
                              'Подробнее',
                              style: TextStyle(
                                  color: AppColors.textHint, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      _ActionButton(
                        icon: Icons.favorite_rounded,
                        color: AppColors.primary,
                        onTap: () => _throwCard(true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Все просмотрено!',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Следи за новыми событиями в ленте',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => ref.read(swipeProvider.notifier).reload(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Обновить',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: AppColors.textHint, size: 48),
            const SizedBox(height: 16),
            const Text('Не удалось загрузить события',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => ref.read(swipeProvider.notifier).reload(),
              child: const Text('Попробовать снова',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

// ─── Back card (visual depth only) ────────────────────────────────────────

class _BackCard extends StatelessWidget {
  final EventModel event;
  final double width, height, scale, offsetY;

  const _BackCard({
    required this.event,
    required this.width,
    required this.height,
    required this.scale,
    required this.offsetY,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offsetY),
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: width,
          height: height,
          child: _EventCard(event: event),
        ),
      ),
    );
  }
}

// ─── Event card content ────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final EventModel event;
  const _EventCard({required this.event});

  static Color _accent(String? alias) {
    const sport = {'football', 'running', 'skating', 'yoga', 'cycling', 'hiking'};
    const ent = {'party', 'concert', 'cinema', 'standup', 'club'};
    const food = {'bar', 'dinner', 'brunch', 'picnic', 'camping'};
    if (sport.contains(alias)) return const Color(0xFF00B4D8);
    if (ent.contains(alias)) return const Color(0xFFFF6B6B);
    if (food.contains(alias)) return const Color(0xFFFFB347);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMMM, HH:mm', 'ru').format(event.startTime);
    final accent = _accent(event.categoryAlias);

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        color: Color(0xFF0D1117),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          if (event.coverUrl != null)
            Image.network(
              event.coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _gradientBg(accent),
            )
          else
            _gradientBg(accent),

          // Dark bottom gradient
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x33000000),
                  Color(0xBB000000),
                  Color(0xEE000000),
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges
                Row(
                  children: [
                    if (event.status == EventStatus.ongoing)
                      _chip('● Идёт сейчас', AppColors.success),
                    if (event.isPrivate)
                      _chip('🔒 Закрытое', AppColors.secondary),
                    if (event.isFull)
                      _chip('Мест нет', AppColors.error),
                  ],
                ),
                const Spacer(),
                Text(event.categoryEmoji,
                    style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 10),
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                _metaRow(Icons.calendar_today_rounded, dateStr),
                const SizedBox(height: 6),
                _metaRow(Icons.location_city_rounded, event.cityName),
                if (event.membersCount > 0) ...[
                  const SizedBox(height: 6),
                  _metaRow(
                    Icons.group_rounded,
                    '${event.membersCount} человек идут',
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gradientBg(Color accent) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.28),
              const Color(0xFF0D1117),
              AppColors.secondary.withValues(alpha: 0.15),
            ],
          ),
        ),
      );

  static Widget _chip(String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
      );

  static Widget _metaRow(IconData icon, String text, {Color? color}) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight:
                  color != null ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Swipe direction overlay ───────────────────────────────────────────────

class _SwipeOverlay extends StatelessWidget {
  final String label;
  final Color color;
  final Alignment alignment;
  final double opacity;

  const _SwipeOverlay({
    required this.label,
    required this.color,
    required this.alignment,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color, width: 3),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Transform.rotate(
              angle: alignment == Alignment.topLeft ? -0.35 : 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Action button ─────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
              color: color.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 18,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
