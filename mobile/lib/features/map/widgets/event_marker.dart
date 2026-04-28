import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';

class EventMarker extends StatelessWidget {
  final EventModel event;
  final bool isSelected;
  final VoidCallback onTap;

  const EventMarker({
    super.key,
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  Color get _markerColor {
    if (event.isPrivate) return const Color(0xFF6B21A8);
    if (event.status == EventStatus.ongoing) return AppColors.success;
    return _colorForAlias(event.categoryAlias ?? '');
  }

  static Color _colorForAlias(String alias) {
    const sport = {'football', 'running', 'skating', 'yoga', 'cycling', 'hiking'};
    const entertainment = {'party', 'concert', 'cinema', 'standup', 'club'};
    const social = {'bar', 'dinner', 'brunch', 'picnic', 'camping'};
    const business = {'lecture', 'workshop', 'meetup', 'it', 'business', 'startup'};
    if (sport.contains(alias)) return const Color(0xFF00B4D8);
    if (entertainment.contains(alias)) return const Color(0xFFFF6B6B);
    if (social.contains(alias)) return const Color(0xFFFFB347);
    if (business.contains(alias)) return const Color(0xFF7C6AF2);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (event.isPrivate) return _buildMysteryMarker();
    return _buildNormalMarker();
  }

  Widget _buildMysteryMarker() {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 14 : 10,
              vertical: isSelected ? 8 : 6,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6B21A8)
                  : const Color(0xFF1A0A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6B21A8),
                width: isSelected ? 0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B21A8)
                      .withValues(alpha: isSelected ? 0.7 : 0.4),
                  blurRadius: isSelected ? 24 : 12,
                  spreadRadius: isSelected ? 4 : 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 13)),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Закрытое событие',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CustomPaint(
            size: const Size(10, 6),
            painter: _MarkerTailPainter(
              color: isSelected
                  ? const Color(0xFF6B21A8)
                  : const Color(0xFF1A0A2E),
              borderColor: const Color(0xFF6B21A8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalMarker() {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 10,
                vertical: isSelected ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? _markerColor : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _markerColor,
                  width: isSelected ? 0 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _markerColor.withValues(alpha: isSelected ? 0.5 : 0.2),
                    blurRadius: isSelected ? 20 : 8,
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.categoryEmoji,
                    style: TextStyle(fontSize: isSelected ? 16 : 13),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          color: AppColors.background,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            CustomPaint(
              size: const Size(10, 6),
              painter: _MarkerTailPainter(
                color: isSelected ? _markerColor : AppColors.surface,
                borderColor: _markerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  _MarkerTailPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTailPainter oldDelegate) =>
      color != oldDelegate.color;
}
