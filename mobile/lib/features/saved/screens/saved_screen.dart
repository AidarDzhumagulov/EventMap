import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../event/screens/event_detail_screen.dart';

final savedEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final response = await dio.get('/events/saved');
  final data = response.data as List<dynamic>;
  return data
      .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(savedEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Сохранённые',
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
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Не удалось загрузить сохранённые события',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(savedEventsProvider),
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.primary),
                        label: const Text('Повторить',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                data: (events) => events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              color: AppColors.textHint,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Нет сохранённых событий',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async =>
                            ref.invalidate(savedEventsProvider),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _SavedEventCard(
                            event: events[i],
                            onUnsave: () async {
                              final dio = ref.read(dioClientProvider);
                              await dio.delete('/events/save',
                                  queryParameters: {'id': events[i].id});
                              ref.invalidate(savedEventsProvider);
                            },
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

class _SavedEventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onUnsave;

  const _SavedEventCard({required this.event, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM, HH:mm', 'ru').format(event.startTime);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EventDetailScreen(event: event),
      )),
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
                color: event.status == EventStatus.ongoing
                    ? AppColors.success
                    : event.status == EventStatus.finished
                        ? AppColors.textHint
                        : AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr · ${event.cityName}',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUnsave,
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
