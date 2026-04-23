import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../providers/events_provider.dart';

class EventBottomSheet extends ConsumerWidget {
  const EventBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEvent = ref.watch(selectedEventProvider);

    if (selectedEvent == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {},
      child: DraggableScrollableSheet(
        initialChildSize: 0.38,
        minChildSize: 0.38,
        maxChildSize: 0.75,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(color: AppColors.glassBorder, width: 1),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildHandle(),
                _buildEventCard(context, selectedEvent, ref),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.glassBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEventCard(
      BuildContext context, EventModel event, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopRow(context, event, ref),
          const SizedBox(height: 16),
          _buildTitle(context, event),
          const SizedBox(height: 8),
          _buildDescription(context, event),
          const SizedBox(height: 20),
          _buildMetaRow(context, event),
          const SizedBox(height: 24),
          _buildActionButton(event),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, EventModel event, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Категория + статус
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Text(
                '${event.categoryEmoji} ${event.category}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            if (event.status == EventStatus.ongoing)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.success.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Идёт сейчас',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                    ),
                  ],
                ),
              ),
            if (event.isPrivate)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.secondary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: AppColors.secondary, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Закрытое',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: AppColors.secondary,
                          ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // Закрыть
        GestureDetector(
          onTap: () => ref.read(selectedEventProvider.notifier).state = null,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.glassBackground,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context, EventModel event) {
    return Text(
      event.title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildDescription(BuildContext context, EventModel event) {
    return Text(
      event.description,
      style: Theme.of(context).textTheme.bodyMedium,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMetaRow(BuildContext context, EventModel event) {
    final timeStr = DateFormat('d MMM, HH:mm', 'ru').format(event.startTime);

    return Row(
      children: [
        _metaChip(
          context,
          icon: Icons.schedule_rounded,
          label: event.timeLabel,
          sublabel: timeStr,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _metaChip(
          context,
          icon: Icons.group_rounded,
          label: event.maxMembers != null
              ? '${event.membersCount}/${event.maxMembers}'
              : '${event.membersCount} чел.',
          sublabel: event.isFull ? 'Мест нет' : 'Участники',
          color: event.isFull ? AppColors.error : AppColors.secondary,
        ),
        const SizedBox(width: 12),
        _metaChip(
          context,
          icon: Icons.location_on_rounded,
          label: event.cityName,
          sublabel: 'Город',
          color: AppColors.textSecondary,
        ),
      ],
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sublabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(EventModel event) {
    if (event.isFull) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const Center(
          child: Text(
            'Мест нет',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return NeonButton(
      label: event.isPrivate ? '🔒  Подать заявку' : '✓  Иду',
      onPressed: () {
        // TODO: join event API
      },
      color: event.isPrivate ? AppColors.secondary : AppColors.primary,
    );
  }
}
