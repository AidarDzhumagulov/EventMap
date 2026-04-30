import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme.dart';

/// Базовый shimmer-блок с цветами под dark-тему приложения.
/// Используется как контейнер для любых скелетонов.
class _ShimmerBox extends StatelessWidget {
  final Widget child;
  const _ShimmerBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.surface,
      child: child,
    );
  }
}

Widget _bar({double? width, double height = 12, double radius = 6}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Скелетон карточки события для feed/saved/swipe.
class EventCardSkeleton extends StatelessWidget {
  final bool withCover;
  const EventCardSkeleton({super.key, this.withCover = true});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withCover)
              Container(height: 160, color: AppColors.surfaceVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bar(width: 80, height: 20, radius: 10),
                      const SizedBox(width: 8),
                      _bar(width: 60, height: 20, radius: 10),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _bar(width: double.infinity, height: 18),
                  const SizedBox(height: 8),
                  _bar(width: 200, height: 14),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _bar(width: 90, height: 12),
                      const SizedBox(width: 16),
                      _bar(width: 60, height: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Скелетон одной строки в списке Saved (без обложки, компактный).
class SavedListItemSkeleton extends StatelessWidget {
  const SavedListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: double.infinity, height: 15),
                  const SizedBox(height: 8),
                  _bar(width: 140, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Список из N карточек-скелетонов — для FeedScreen / SwipeScreen.
class EventListSkeleton extends StatelessWidget {
  final int count;
  final bool withCover;
  const EventListSkeleton({super.key, this.count = 5, this.withCover = true});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => EventCardSkeleton(withCover: withCover),
    );
  }
}
