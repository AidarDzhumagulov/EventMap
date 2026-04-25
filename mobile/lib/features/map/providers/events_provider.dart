import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/event_model.dart';
import '../repository/category_repository.dart';
import '../repository/event_repository.dart';

final selectedCityProvider = StateProvider<String>((ref) => 'Бишкек');

final mapCenterProvider = StateProvider<LatLng>(
  (ref) => const LatLng(42.8746, 74.5698),
);

// null = все категории
final selectedCategoryTypeIdProvider = StateProvider<int?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

final eventsProvider =
    FutureProvider.family<List<EventModel>, String>((ref, city) async {
  final search = ref.watch(searchQueryProvider);
  return ref.read(eventRepositoryProvider).getEvents(city: city, search: search);
});

// События отфильтрованные по типу категории
final filteredEventsProvider =
    Provider.family<AsyncValue<List<EventModel>>, String>((ref, city) {
  final eventsAsync = ref.watch(eventsProvider(city));
  final selectedTypeId = ref.watch(selectedCategoryTypeIdProvider);
  final categoriesAsync = ref.watch(categoriesProvider);

  if (selectedTypeId == null) return eventsAsync;

  return eventsAsync.whenData((events) {
    // Строим маппинг category_id → category_type_id
    final categoryTypeMap = <int, int>{};
    categoriesAsync.whenData((types) {
      for (final type in types) {
        for (final cat in type.categories) {
          categoryTypeMap[cat.id] = type.id;
        }
      }
    });

    return events.where((e) {
      if (e.categoryId == null) return false;
      return categoryTypeMap[e.categoryId] == selectedTypeId;
    }).toList();
  });
});

final selectedEventProvider = StateProvider<EventModel?>((ref) => null);
