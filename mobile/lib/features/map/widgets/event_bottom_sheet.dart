import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../event/screens/event_detail_screen.dart';
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
                if (selectedEvent.coverUrl != null)
                  ClipRRect(
                    child: Image.network(
                      selectedEvent.coverUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
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
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EventDetailScreen(event: event),
            )),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.glassBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Center(
                child: Text('Подробнее →',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionButton(event, ref, context),
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

  Widget _buildActionButton(EventModel event, WidgetRef ref, BuildContext context) {
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

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: NeonButton(
            label: '✓  Иду',
            onPressed: () => _joinEvent(event, ref, context, status: 'go'),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statusChip(
            icon: Icons.help_outline_rounded,
            tooltip: 'Подумаю',
            onTap: () => _joinEvent(event, ref, context, status: 'think'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statusChip(
            icon: Icons.close_rounded,
            tooltip: 'Не пойду',
            onTap: () => _joinEvent(event, ref, context, status: 'decline'),
          ),
        ),
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }

  Future<void> _joinEvent(
      EventModel event, WidgetRef ref, BuildContext context,
      {String status = 'go'}) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post('/events/join',
          queryParameters: {'id': event.id, 'status': status});
      if (context.mounted) {
        final labels = {'go': 'Ты идёшь! 🎉', 'think': 'Отмечено — подумаешь 🤔', 'decline': 'Отказался 👋'};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(labels[status] ?? 'Готово'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      ref.invalidate(eventsProvider(event.cityName));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось обновить статус'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
