import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/snackbar.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../event/screens/event_detail_screen.dart';
import '../../event/widgets/rsvp_buttons.dart';
import '../../saved/providers/saved_provider.dart';
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
                    child: CachedNetworkImage(
                      imageUrl: selectedEvent.coverUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: AppColors.surfaceVariant,
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
          RsvpButtons(
            eventId: event.id,
            cityName: event.cityName,
            isFull: event.isFull,
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, EventModel event, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Категория + статус
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.status == EventStatus.ongoing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
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
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded,
                          color: AppColors.secondary, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Закрытое',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: AppColors.secondary,
                                ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SaveButton(event: event),
            const SizedBox(width: 8),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

}

class _SaveButton extends ConsumerWidget {
  final EventModel event;
  const _SaveButton({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedEventsProvider);
    final isSaved = ref.watch(isSavedProvider(event.id));

    return GestureDetector(
      onTap: savedAsync.isLoading
          ? null
          : () async {
              try {
                await ref.read(savedEventsProvider.notifier).toggle(event);
              } catch (e) {
                if (context.mounted) context.showApiError(e);
              }
            },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: savedAsync.isLoading
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.primary),
              )
            : Icon(
                isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isSaved ? Colors.redAccent : AppColors.textSecondary,
                size: 16,
              ),
      ),
    );
  }
}
