import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/event_model.dart';
import '../repository/category_repository.dart';
import '../repository/event_repository.dart';

enum DateFilter { all, today, thisWeek }

final selectedCityProvider = StateProvider<String>((ref) => 'Бишкек');

final mapCenterProvider = StateProvider<LatLng>(
  (ref) => const LatLng(42.8746, 74.5698),
);

final selectedCategoryTypeIdProvider = StateProvider<int?>((ref) => null);
final selectedDateFilterProvider = StateProvider<DateFilter>((ref) => DateFilter.all);
final searchQueryProvider = StateProvider<String>((ref) => '');

final eventsProvider =
    FutureProvider.family<List<EventModel>, String>((ref, city) async {
  final search = ref.watch(searchQueryProvider);
  return ref.read(eventRepositoryProvider).getEvents(city: city, search: search);
});

final filteredEventsProvider =
    Provider.family<AsyncValue<List<EventModel>>, String>((ref, city) {
  final eventsAsync = ref.watch(eventsProvider(city));
  final selectedTypeId = ref.watch(selectedCategoryTypeIdProvider);
  final dateFilter = ref.watch(selectedDateFilterProvider);
  final categoriesAsync = ref.watch(categoriesProvider);

  return eventsAsync.whenData((events) {
    var filtered = events;

    if (selectedTypeId != null) {
      final categoryTypeMap = <int, int>{};
      categoriesAsync.whenData((types) {
        for (final type in types) {
          for (final cat in type.categories) {
            categoryTypeMap[cat.id] = type.id;
          }
        }
      });
      filtered = filtered.where((e) {
        if (e.categoryId == null) return false;
        return categoryTypeMap[e.categoryId] == selectedTypeId;
      }).toList();
    }

    final now = DateTime.now();
    switch (dateFilter) {
      case DateFilter.today:
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        filtered = filtered
            .where((e) =>
                e.startTime.isAfter(startOfDay) &&
                e.startTime.isBefore(endOfDay))
            .toList();
      case DateFilter.thisWeek:
        final endOfWeek = now.add(const Duration(days: 7));
        filtered = filtered
            .where((e) =>
                e.startTime.isAfter(now) && e.startTime.isBefore(endOfWeek))
            .toList();
      case DateFilter.all:
        break;
    }

    return filtered;
  });
});

final selectedEventProvider = StateProvider<EventModel?>((ref) => null);
