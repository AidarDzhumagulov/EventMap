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
    if (event.isPrivate) return AppColors.secondary;
    if (event.status == EventStatus.ongoing) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bubble
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
                    color: _markerColor.withOpacity(isSelected ? 0.5 : 0.2),
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
                    Text(
                      event.title,
                      style: TextStyle(
                        color: AppColors.background,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Хвостик
            CustomPaint(
              size: const Size(10, 6),
              painter: _MarkerTailPainter(
                color: isSelected ? _markerColor : AppColors.surface,
                borderColor: isSelected ? _markerColor : _markerColor,
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
