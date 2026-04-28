import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';

// Публичный метод — вызываем из detail screen
Future<void> shareEvent(
  BuildContext context,
  EventModel event, {
  Rect? sharePositionOrigin,
}) async {
  final controller = ScreenshotController();
  final Uint8List bytes = await controller.captureFromLongWidget(
    EventShareCard(event: event),
    pixelRatio: 3.0,
    context: context,
  );
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: 'event.png', mimeType: 'image/png')],
    text: '${event.title} — EventMap',
    sharePositionOrigin: sharePositionOrigin,
  );
}

class EventShareCard extends StatelessWidget {
  final EventModel event;
  const EventShareCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMMM, HH:mm', 'ru').format(event.startTime);
    final hasCover = event.coverUrl != null;

    return Container(
      width: 380,
      height: 580,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(28)),
        color: Color(0xFF080C18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover-фото с затемнением или чистый фон
          if (hasCover)
            Image.network(event.coverUrl!, fit: BoxFit.cover)
          else
            _GradientBackground(categoryAlias: event.categoryAlias ?? ''),

          // Затемняющий оверлей поверх обложки
          if (hasCover)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0xCC000000),
                    Color(0xF5000000),
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),

          // Контент
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Шапка: бренд + статус
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _Badge(
                      label: 'EventMap',
                      color: AppColors.primary,
                      filled: false,
                    ),
                    if (event.status == EventStatus.ongoing)
                      const _Badge(label: '● Идёт сейчас', color: AppColors.success, filled: true),
                  ],
                ),

                const Spacer(),

                // Эмодзи категории
                Text(event.categoryEmoji, style: const TextStyle(fontSize: 52)),
                const SizedBox(height: 12),

                // Название события
                Text(
                  event.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),

                // Мета-информация
                _MetaRow(icon: Icons.calendar_today_rounded, text: dateStr),
                const SizedBox(height: 6),
                _MetaRow(icon: Icons.location_city_rounded, text: event.cityName),
                if (event.membersCount > 0) ...[
                  const SizedBox(height: 6),
                  _MetaRow(
                    icon: Icons.group_rounded,
                    text: '${event.membersCount} человек ${event.membersCount == 1 ? "идёт" : "идут"}',
                    highlight: true,
                  ),
                ],

                const SizedBox(height: 24),

                // CTA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.12),
                        AppColors.primary.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: const Text(
                    'Я иду сюда. А ты?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Подпись
                const Center(
                  child: Text(
                    'Найди своё событие → eventmap.app',
                    style: TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Градиентный фон — цвет зависит от категории
class _GradientBackground extends StatelessWidget {
  final String categoryAlias;
  const _GradientBackground({required this.categoryAlias});

  static Color _accent(String alias) {
    const sport = {'football', 'running', 'skating', 'yoga', 'cycling', 'hiking'};
    const entertainment = {'party', 'concert', 'cinema', 'standup', 'club'};
    const food = {'bar', 'dinner', 'brunch', 'picnic', 'camping'};
    if (sport.contains(alias)) return const Color(0xFF00B4D8);
    if (entertainment.contains(alias)) return const Color(0xFFFF6B6B);
    if (food.contains(alias)) return const Color(0xFFFFB347);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent(categoryAlias);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Glow сверху-справа
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Glow снизу-слева (secondary фиолетовый)
        Positioned(
          bottom: -40,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Badge({required this.label, required this.color, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;

  const _MetaRow({required this.icon, required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textSecondary;
    return Row(
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
