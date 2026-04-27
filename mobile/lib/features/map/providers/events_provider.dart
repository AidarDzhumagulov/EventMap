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

final eventByIdProvider = FutureProvider.family<EventModel, String>((ref, id) {
  return ref.read(eventRepositoryProvider).getEvent(id);
});

// ─── Paginated feed ────────────────────────────────────────────────────────

class PaginatedEventsState {
  final List<EventModel> events;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const PaginatedEventsState({
    this.events = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  PaginatedEventsState withMore(List<EventModel> newPage, int pageSize) {
    return PaginatedEventsState(
      events: [...events, ...newPage],
      isLoadingMore: false,
      hasMore: newPage.length == pageSize,
    );
  }
}

class PaginatedEventsNotifier extends AutoDisposeNotifier<PaginatedEventsState> {
  static const _pageSize = 30;
  int _offset = 0;

  @override
  PaginatedEventsState build() {
    final city = ref.watch(selectedCityProvider);
    final search = ref.watch(searchQueryProvider);
    _offset = 0;
    _fetch(city: city, search: search, reset: true);
    return const PaginatedEventsState(isLoading: true);
  }

  Future<void> _fetch({
    required String city,
    required String search,
    bool reset = false,
  }) async {
    try {
      final events = await ref.read(eventRepositoryProvider).getEvents(
            city: city,
            search: search,
            limit: _pageSize,
            offset: _offset,
          );
      _offset += events.length;
      if (reset) {
        state = PaginatedEventsState(
          events: events,
          isLoading: false,
          hasMore: events.length == _pageSize,
        );
      } else {
        state = state.withMore(events, _pageSize);
      }
    } catch (e) {
      state = PaginatedEventsState(
        events: reset ? const [] : state.events,
        isLoading: false,
        isLoadingMore: false,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = PaginatedEventsState(
      events: state.events,
      isLoading: false,
      isLoadingMore: true,
      hasMore: state.hasMore,
    );
    final city = ref.read(selectedCityProvider);
    final search = ref.read(searchQueryProvider);
    await _fetch(city: city, search: search);
  }

  Future<void> refresh() async {
    _offset = 0;
    state = const PaginatedEventsState(isLoading: true);
    final city = ref.read(selectedCityProvider);
    final search = ref.read(searchQueryProvider);
    await _fetch(city: city, search: search, reset: true);
  }
}

final paginatedEventsProvider =
    AutoDisposeNotifierProvider<PaginatedEventsNotifier, PaginatedEventsState>(
  PaginatedEventsNotifier.new,
);
