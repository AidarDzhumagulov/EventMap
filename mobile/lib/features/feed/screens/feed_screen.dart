import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../event/screens/event_detail_screen.dart';
import '../../map/providers/events_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCity = ref.watch(selectedCityProvider);
    final eventsAsync = ref.watch(filteredEventsProvider(selectedCity));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Лента',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: eventsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => const Center(
                  child: Text(
                    'Не удалось загрузить события',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                data: (events) => events.isEmpty
                    ? const Center(
                        child: Text(
                          'Событий пока нет',
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async =>
                            ref.invalidate(eventsProvider(selectedCity)),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EventDetailScreen(event: events[i]),
                              ),
                            ),
                            child: _EventCard(event: events[i]),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventModel event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        DateFormat('d MMM, HH:mm', 'ru').format(event.startTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Верхняя строка: статус + приватность
          Row(
            children: [
              _badge(
                label: event.timeLabel,
                color: event.status == EventStatus.ongoing
                    ? AppColors.success
                    : AppColors.primary,
              ),
              if (event.isPrivate) ...[
                const SizedBox(width: 8),
                _badge(label: '🔒 Закрытое', color: AppColors.secondary),
              ],
              const Spacer(),
              Text(
                event.cityName,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Название
          Text(
            event.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // Нижняя строка: время + участники
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.textHint, size: 14),
              const SizedBox(width: 4),
              Text(
                timeStr,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 12),
              ),
              if (event.maxMembers != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.group_rounded,
                    color: AppColors.textHint, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${event.membersCount}/${event.maxMembers}',
                  style: TextStyle(
                    color: event.isFull
                        ? AppColors.error
                        : AppColors.textHint,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
