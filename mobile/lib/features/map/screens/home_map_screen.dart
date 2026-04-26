import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../event/screens/event_detail_screen.dart';
import '../../feed/screens/feed_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../saved/screens/saved_screen.dart';
import '../providers/events_provider.dart';
import '../repository/category_repository.dart';
import '../widgets/event_bottom_sheet.dart';
import '../widgets/event_marker.dart';
import 'create_event_screen.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  int _selectedNavIndex = 0;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  static const _dgisApiKey = String.fromEnvironment('DGIS_API_KEY');
  static const _2gisTile =
      'https://tile2.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1&r=g&ts=online_sd&key=$_dgisApiKey';

  @override
  Widget build(BuildContext context) {
    final selectedCity = ref.watch(selectedCityProvider);
    final eventsAsync = ref.watch(filteredEventsProvider(selectedCity));
    final selectedEvent = ref.watch(selectedEventProvider);
    final mapCenter = ref.watch(mapCenterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: _selectedNavIndex == 0,
      body: _selectedNavIndex == 3
          ? const ProfileScreen()
          : _selectedNavIndex == 2
              ? const SavedScreen()
              : _selectedNavIndex == 1
                  ? const FeedScreen()
                  : Stack(
        children: [
          // Карта
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 19,
              onTap: (_, __) {
                ref.read(selectedEventProvider.notifier).state = null;
              },
            ),
            children: [
              // Тайлы карты
              TileLayer(
                urlTemplate: _2gisTile,
                userAgentPackageName: 'com.eventmap.event_map',
                maxZoom: 19,
              ),
              // Маркеры событий
              MarkerLayer(
                markers: eventsAsync.maybeWhen(
                  data: (events) => events.map((event) {
                    final isSelected = selectedEvent?.id == event.id;
                    return Marker(
                      point: event.location,
                      width: isSelected ? 160 : 60,
                      height: 56,
                      alignment: Alignment.topCenter,
                      child: EventMarker(
                        event: event,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedEventProvider.notifier).state =
                              event;
                          _mapController.move(event.location, 14);
                        },
                      ),
                    );
                  }).toList(),
                  orElse: () => [],
                ),
              ),
            ],
          ),

          // Верхний градиент + шапка
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.95),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Row(
                    children: [
                      _buildSearchBar(),
                      const SizedBox(width: 12),
                      _buildCitySelector(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Фильтры категорий
          Positioned(
            top: MediaQuery.of(context).padding.top + 76,
            left: 0,
            right: 0,
            child: _buildCategoryFilters(),
          ),

          // Результаты поиска
          _buildSearchResults(eventsAsync),

          // Индикатор загрузки / ошибки
          eventsAsync.when(
            data: (_) => const SizedBox.shrink(),
            loading: () => const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                color: AppColors.primary,
                minHeight: 2,
              ),
            ),
            error: (e, _) => Positioned(
              bottom: 120,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: const Text(
                  'Не удалось загрузить события',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Кнопка "моё местоположение"
          Positioned(
            bottom: selectedEvent != null ? 320 : 110,
            right: 16,
            child: _buildLocationButton(),
          ),

          // Bottom sheet события
          if (selectedEvent != null)
            Positioned.fill(
              child: const EventBottomSheet(),
            ),
        ],
      ),

      // FAB — добавить событие (только на вкладке карты)

      floatingActionButton: _selectedNavIndex == 0 && selectedEvent == null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  final center = ref.read(mapCenterProvider);
                  final city = ref.read(selectedCityProvider);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateEventScreen(
                        initialLat: center.latitude,
                        initialLon: center.longitude,
                        initialCity: city,
                      ),
                    ),
                  );
                },
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Создать событие',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // Bottom navigation bar — скрываем только когда открыт bottom sheet на карте
      bottomNavigationBar:
          (_selectedNavIndex == 0 && selectedEvent != null)
              ? null
              : _buildBottomNavBar(),
    );
  }

  Widget _buildSearchBar() {
    final query = ref.watch(searchQueryProvider);
    return Expanded(
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: query.isNotEmpty ? AppColors.primary : AppColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textHint, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Поиск событий...',
                  hintStyle:
                      TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                    ref.read(searchQueryProvider.notifier).state = value;
                  });
                },
              ),
            ),
            if (query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                },
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textHint, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    return Consumer(
      builder: (context, ref, _) {
        final city = ref.watch(selectedCityProvider);
        return GestureDetector(
          onTap: () => _showCityPicker(context, ref),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_city_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  city,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCityPicker(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выбери город',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Введи название города...',
                hintStyle: const TextStyle(color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                if (value.trim().isEmpty) return;
                ref.read(selectedCityProvider.notifier).state = value.trim();
                ref.read(selectedEventProvider.notifier).state = null;
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Популярные города',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _cityOption(context, ref, 'Бишкек', LatLng(42.8746, 74.5698)),
            const SizedBox(height: 8),
            _cityOption(context, ref, 'Алматы', LatLng(43.2220, 76.8512)),
            const SizedBox(height: 8),
            _cityOption(context, ref, 'Астана', LatLng(51.1694, 71.4491)),
            const SizedBox(height: 8),
            _cityOption(context, ref, 'Ташкент', LatLng(41.2995, 69.2401)),
          ],
        ),
      ),
    );
  }

  Widget _cityOption(
      BuildContext context, WidgetRef ref, String city, LatLng coords) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedCityProvider.notifier).state = city;
        ref.read(mapCenterProvider.notifier).state = coords;
        ref.read(selectedEventProvider.notifier).state = null;
        _mapController.move(coords, 13);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(city, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<EventModel>> eventsAsync) {
    final query = ref.watch(searchQueryProvider);
    if (query.isEmpty) return const SizedBox.shrink();

    final topOffset = MediaQuery.of(context).padding.top + 80.0;

    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: eventsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ошибка поиска',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            data: (events) => events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.search_off_rounded,
                            color: AppColors.textHint, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'По запросу «$query» ничего не найдено',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.glassBorder,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, i) {
                      final event = events[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${event.cityName} · ${event.timeLabel}',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textHint, size: 20),
                        onTap: () {
                          // Сбрасываем поиск и открываем детали
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => EventDetailScreen(event: event),
                          ));
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedTypeId = ref.watch(selectedCategoryTypeIdProvider);

    final types = categoriesAsync.maybeWhen(data: (t) => t, orElse: () => []);

    final chips = [
      (null, 'Все', '🌍'),
      ...types.map((t) => (t.id, t.nameRu, '📌')),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (id, label, emoji) = chips[index];
          final isActive = id == selectedTypeId;
          return GestureDetector(
            onTap: () {
              ref.read(selectedCategoryTypeIdProvider.notifier).state = id;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isActive ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isActive ? AppColors.primary : AppColors.glassBorder,
                ),
              ),
              child: Text(
                '$emoji $label',
                style: TextStyle(
                  color: isActive
                      ? AppColors.background
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      15,
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: _goToMyLocation,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(Icons.my_location_rounded,
            color: AppColors.primary, size: 22),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.map_rounded, 'Карта'),
              _navItem(1, Icons.explore_rounded, 'Лента'),
              _navItem(2, Icons.favorite_border_rounded, 'Сохранённые'),
              _navItem(3, Icons.person_outline_rounded, 'Профиль'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        if (isSelected && index == 0) {
          final city = ref.read(selectedCityProvider);
          ref.invalidate(eventsProvider(city));
        }
        setState(() => _selectedNavIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textHint,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textHint,
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
