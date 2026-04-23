import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../providers/events_provider.dart';
import '../widgets/event_bottom_sheet.dart';
import '../widgets/event_marker.dart';

class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  final MapController _mapController = MapController();
  int _selectedNavIndex = 0;

  // OpenStreetMap tile — бесплатно, без ключа
  // Для переключения на 2GIS — меняем urlTemplate
  static const _osmTile =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // 2GIS tile (требует API ключ, раскомментить когда будет готов):
  // static const _2gisTile =
  //     'https://tile2.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1&r=g&ts=online_sd';

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);
    final selectedEvent = ref.watch(selectedEventProvider);
    final mapCenter = ref.watch(mapCenterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
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
                urlTemplate: _osmTile,
                userAgentPackageName: 'com.eventmap.event_map',
                maxZoom: 19,
              ),
              // Маркеры событий
              MarkerLayer(
                markers: events.map((event) {
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
                        ref.read(selectedEventProvider.notifier).state = event;
                        _mapController.move(event.location, 14);
                      },
                    ),
                  );
                }).toList(),
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

          // Кнопка "моё местоположение"
          Positioned(
            bottom: selectedEvent != null ? 320 : 110,
            right: 16,
            child: _buildLocationButton(),
          ),

          // Bottom sheet события
          if (selectedEvent != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: const EventBottomSheet(),
            ),
        ],
      ),

      // FAB — добавить событие
      floatingActionButton: selectedEvent == null
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
                  // TODO: create event screen
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

      // Bottom navigation bar
      bottomNavigationBar: selectedEvent == null
          ? _buildBottomNavBar()
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // TODO: search screen
        },
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: AppColors.textHint, size: 20),
              const SizedBox(width: 10),
              Text(
                'Поиск событий...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    return Consumer(
      builder: (context, ref, _) {
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
            child: const Row(
              children: [
                Icon(Icons.location_city_rounded,
                    color: AppColors.primary, size: 18),
                SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCityPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выбери город',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            _cityOption(context, ref, 'Бишкек', LatLng(42.8746, 74.5698)),
            const SizedBox(height: 12),
            _cityOption(context, ref, 'Алматы', LatLng(43.2220, 76.8512)),
          ],
        ),
      ),
    );
  }

  Widget _cityOption(
      BuildContext context, WidgetRef ref, String city, LatLng coords) {
    return GestureDetector(
      onTap: () {
        ref.read(mapCenterProvider.notifier).state = coords;
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

  Widget _buildCategoryFilters() {
    final categories = [
      ('Все', '🌍'),
      ('Вечеринки', '🎉'),
      ('Спорт', '🛹'),
      ('Музыка', '🎷'),
      ('IT', '💻'),
      ('Еда', '🍽️'),
      ('Отдых', '🧺'),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, emoji) = categories[index];
          final isActive = index == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.glassBorder,
              ),
            ),
            child: Text(
              '$emoji $label',
              style: TextStyle(
                color:
                    isActive ? AppColors.background : AppColors.textSecondary,
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: () {
        // TODO: get real user location
        _mapController.move(LatLng(42.8746, 74.5698), 14);
      },
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
      onTap: () => setState(() => _selectedNavIndex = index),
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
