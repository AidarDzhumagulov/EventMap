import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../../routes/app_router.dart';
import '../../event/screens/event_detail_screen.dart';
import '../../map/providers/events_provider.dart';
import '../../map/repository/category_repository.dart' show categoriesProvider;

const _dateFilterLabels = {
  DateFilter.all: 'Все',
  DateFilter.today: 'Сегодня',
  DateFilter.thisWeek: 'Эта неделя',
};

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedEventsProvider.notifier).loadMore();
    }
  }

  List<EventModel> _applyFilters(
    List<EventModel> events,
    DateFilter dateFilter,
    int? selectedTypeId,
    Map<int, int> categoryTypeMap,
  ) {
    var filtered = events;

    if (selectedTypeId != null) {
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
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(paginatedEventsProvider);
    final dateFilter = ref.watch(selectedDateFilterProvider);
    final selectedTypeId = ref.watch(selectedCategoryTypeIdProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final categoryTypeMap = <int, int>{};
    categoriesAsync.whenData((types) {
      for (final type in types) {
        for (final cat in type.categories) {
          categoryTypeMap[cat.id] = type.id;
        }
      }
    });

    final visibleEvents = _applyFilters(
      feedState.events,
      dateFilter,
      selectedTypeId,
      categoryTypeMap,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Лента',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const _SwipeBanner(),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: DateFilter.values.map((filter) {
                  final isActive = dateFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => ref
                          .read(selectedDateFilterProvider.notifier)
                          .state = filter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.glassBorder,
                          ),
                        ),
                        child: Text(
                          _dateFilterLabels[filter]!,
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
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: feedState.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    )
                  : feedState.error != null && feedState.events.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Не удалось загрузить события',
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () => ref
                                    .read(paginatedEventsProvider.notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh_rounded,
                                    color: AppColors.primary),
                                label: const Text('Повторить',
                                    style:
                                        TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => ref
                              .read(paginatedEventsProvider.notifier)
                              .refresh(),
                          child: visibleEvents.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Событий пока нет',
                                    style: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 100),
                                  itemCount: visibleEvents.length +
                                      (feedState.isLoadingMore ? 1 : 0),
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    if (i == visibleEvents.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    return GestureDetector(
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => EventDetailScreen(
                                              event: visibleEvents[i]),
                                        ),
                                      ),
                                      child: _EventCard(
                                          event: visibleEvents[i]),
                                    );
                                  },
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.coverUrl != null)
            Image.network(
              event.coverUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
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

// ─── Баннер «Не знаешь куда пойти?» → SwipeScreen ──────────────────────────

class _SwipeBanner extends StatelessWidget {
  const _SwipeBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.swipe),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.22),
                AppColors.secondary.withValues(alpha: 0.18),
              ],
            ),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Не знаешь куда пойти?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Свайпай события — найди своё',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
