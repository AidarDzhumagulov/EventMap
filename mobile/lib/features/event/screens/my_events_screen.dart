import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import 'event_detail_screen.dart';

final myEventsProvider = FutureProvider<List<EventModel>>((ref) async {
  final dio = ref.read(dioClientProvider);
  final response = await dio.get('/events/my');
  final data = response.data as List<dynamic>;
  return data
      .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(myEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Мои события'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: eventsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Text('Не удалось загрузить события',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        data: (events) => events.isEmpty
            ? const Center(
                child: Text('Ты ещё не создал ни одного события',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async => ref.invalidate(myEventsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => EventDetailScreen(event: events[i]),
                    )),
                    child: _MyEventCard(event: events[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MyEventCard extends StatelessWidget {
  final EventModel event;

  const _MyEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM, HH:mm', 'ru').format(event.startTime);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          // Цветной индикатор статуса
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
          if (event.isPrivate)
            const Icon(Icons.lock_rounded,
                color: AppColors.secondary, size: 16),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint, size: 20),
        ],
      ),
    );
  }
}
