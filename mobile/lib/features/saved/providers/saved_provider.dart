import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/event_model.dart';

/// Единый источник правды для сохранённых событий.
/// Один запрос `/events/saved` кэширует весь список — все остальные виджеты
/// (кнопки лайка, экран Избранного) деривируют состояние отсюда.
class SavedEventsNotifier extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() async {
    final dio = ref.read(dioClientProvider);
    final response = await dio.get('/events/saved');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Оптимистичный toggle: сразу меняем стейт, потом дёргаем бэк.
  /// При ошибке откатываемся обратно.
  Future<void> toggle(EventModel event) async {
    final current = state.value ?? const <EventModel>[];
    final wasSaved = current.any((e) => e.id == event.id);

    state = AsyncValue.data(
      wasSaved
          ? current.where((e) => e.id != event.id).toList()
          : [event, ...current],
    );

    try {
      final dio = ref.read(dioClientProvider);
      if (wasSaved) {
        await dio.delete('/events/save', queryParameters: {'id': event.id});
      } else {
        await dio.post('/events/save', queryParameters: {'id': event.id});
      }
    } catch (e) {
      // Откат при сетевой ошибке.
      state = AsyncValue.data(current);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final savedEventsProvider =
    AsyncNotifierProvider<SavedEventsNotifier, List<EventModel>>(
  SavedEventsNotifier.new,
);

/// Реактивный bool: сохранено ли конкретное событие.
/// Использование: `final isSaved = ref.watch(isSavedProvider(eventId));`
final isSavedProvider = Provider.family<bool, String>((ref, eventId) {
  final saved = ref.watch(savedEventsProvider);
  return saved.maybeWhen(
    data: (events) => events.any((e) => e.id == eventId),
    orElse: () => false,
  );
});
