import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme.dart';
import '../../../models/event_model.dart';
import '../../map/providers/events_provider.dart';
import '../../profile/repository/user_repository.dart';
import '../../saved/screens/saved_screen.dart';
import 'edit_event_screen.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isLoading = false;
  bool? _isSaved;
  String? _myStatus; // 'go' | 'think' | 'decline' | null
  late EventModel _event; // локальная копия, обновляется после редактирования

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final dio = ref.read(dioClientProvider);
    await Future.wait([
      _loadSaveState(dio),
      _loadMemberStatus(dio),
    ]);
  }

  Future<void> _loadSaveState(dio) async {
    try {
      final response = await dio.get('/events/is-saved',
          queryParameters: {'id': _event.id});
      final saved = (response.data as Map<String, dynamic>)['saved'] as bool;
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {
      if (mounted) setState(() => _isSaved = false);
    }
  }

  Future<void> _loadMemberStatus(dio) async {
    try {
      final response = await dio.get('/events/my-status',
          queryParameters: {'id': _event.id});
      if (response.statusCode == 200) {
        final status = response.data['status'] as String?;
        if (mounted) setState(() => _myStatus = status);
      }
    } catch (_) {
      // не записан — оставляем null
    }
  }

  Future<void> _toggleSave() async {
    final current = _isSaved ?? false;
    setState(() => _isSaved = !current);
    try {
      final dio = ref.read(dioClientProvider);
      if (current) {
        await dio.delete('/events/save',
            queryParameters: {'id': _event.id});
      } else {
        await dio.post('/events/save',
            queryParameters: {'id': _event.id});
      }
      ref.invalidate(savedEventsProvider);
    } catch (_) {
      if (mounted) setState(() => _isSaved = current);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post('/events/join',
          queryParameters: {'id': _event.id, 'status': status});
      if (mounted) {
        // Оптимистично обновляем счётчик (backend считает только 'go'):
        // null/'think'/'decline' → 'go': +1
        // 'go' → 'think'/'decline': -1
        // остальные переходы: без изменений
        final wasGo = _myStatus == 'go';
        final becomesGo = status == 'go';
        setState(() {
          _myStatus = status;
          if (!wasGo && becomesGo) {
            _event = _event.copyWith(membersCount: _event.membersCount + 1);
          } else if (wasGo && !becomesGo) {
            _event = _event.copyWith(membersCount: _event.membersCount - 1);
          }
        });
        final labels = {
          'go': 'Ты идёшь!',
          'think': 'Отмечено — подумаешь',
          'decline': 'Отказался',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(labels[status] ?? 'Готово'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
        ref.invalidate(eventsProvider(_event.cityName));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось обновить статус'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить событие?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Это действие нельзя отменить.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dio = ref.read(dioClientProvider);
      await dio.delete('/events/delete',
          queryParameters: {'id': _event.id});
      if (mounted) {
        ref.invalidate(eventsProvider(_event.cityName));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Событие удалено'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ошибка удаления'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _event; // используем локальную копию
    final meAsync = ref.watch(meProvider);
    final dateStr =
        DateFormat('d MMMM yyyy, HH:mm', 'ru').format(event.startTime);

    final isCreator = meAsync.maybeWhen(
      data: (me) => me.id == event.createdBy,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Событие'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isCreator) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded,
                  color: AppColors.primary, size: 20),
              onPressed: () async {
                final updated = await Navigator.of(context)
                    .push<EventModel>(MaterialPageRoute(
                  builder: (_) => EditEventScreen(event: _event),
                ));
                if (updated != null && mounted) {
                  setState(() => _event = updated);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              onPressed: _deleteEvent,
            ),
          ],
          IconButton(
            icon: _isSaved == null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : Icon(
                    _isSaved!
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color:
                        _isSaved! ? Colors.redAccent : AppColors.textHint,
                  ),
            onPressed: _isSaved == null ? null : _toggleSave,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Обложка
          if (event.coverUrl != null)
            Container(
              height: 200,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(event.coverUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            spacing: 8,
            children: [
              if (event.status == EventStatus.ongoing)
                _badge('Идёт сейчас', AppColors.success),
              if (event.isPrivate)
                _badge('🔒 Закрытое', AppColors.secondary),
              if (event.isFull)
                _badge('Мест нет', AppColors.error),
            ],
          ),
          const SizedBox(height: 16),

          // Название
          Text(event.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 20),

          // Мета-инфо
          _infoRow(Icons.calendar_today_rounded, 'Начало', dateStr),
          if (event.endTime != null)
            _infoRow(
              Icons.event_available_rounded,
              'Конец',
              DateFormat('d MMMM yyyy, HH:mm', 'ru').format(event.endTime!),
            ),
          _infoRow(Icons.location_city_rounded, 'Город', event.cityName),
          _infoRow(
            Icons.location_on_rounded,
            'Координаты',
            '${event.location.latitude.toStringAsFixed(5)}, ${event.location.longitude.toStringAsFixed(5)}',
          ),
          if (event.maxMembers != null)
            _membersRow(
              '${event.membersCount} / ${event.maxMembers}',
              event.id,
            )
          else if (event.membersCount > 0)
            _membersRow('${event.membersCount}', event.id),
          const SizedBox(height: 20),

          // Описание
          if (event.description.isNotEmpty) ...[
            Text('Описание',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            Text(event.description,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
          ],

          // Мой статус
          if (_myStatus != null) ...[
            _currentStatusBanner(_myStatus!),
            const SizedBox(height: 16),
          ],

          // Кнопки статуса
          if (!event.isFull || event.status == EventStatus.ongoing) ...[
            Text(
              _myStatus == null ? 'Мой статус' : 'Изменить статус',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _actionButton(
                    label: '✓  Иду',
                    color: _myStatus == 'go'
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    textColor: _myStatus == 'go'
                        ? Colors.white
                        : AppColors.textPrimary,
                    onTap: () => _setStatus('go'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _iconButton(
                    icon: Icons.help_outline_rounded,
                    tooltip: 'Подумаю',
                    active: _myStatus == 'think',
                    onTap: () => _setStatus('think'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _iconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Не пойду',
                    active: _myStatus == 'decline',
                    onTap: () => _setStatus('decline'),
                  ),
                ),
              ],
            ),
          ],

          if (event.isFull && _myStatus == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Center(
                child: Text('Мест нет',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currentStatusBanner(String status) {
    final map = {
      'go': ('Ты идёшь!', Icons.check_circle_rounded, AppColors.success),
      'think': ('Думаешь', Icons.help_rounded, AppColors.secondary),
      'decline': ('Не идёшь', Icons.cancel_rounded, AppColors.error),
    };
    final (label, icon, color) = map[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _membersRow(String value, String eventId) {
    return GestureDetector(
      onTap: () => _showMembersSheet(eventId),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.group_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Участники',
                    style: TextStyle(
                        color: AppColors.textHint, fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(value,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14)),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textHint, size: 14),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMembersSheet(String eventId) async {
    final dio = ref.read(dioClientProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MembersSheet(dio: dio, eventId: eventId),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Text(label,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.glassBorder,
            ),
          ),
          child: Icon(icon,
              color: active ? AppColors.primary : AppColors.textSecondary,
              size: 20),
        ),
      ),
    );
  }
}

class _MembersSheet extends StatefulWidget {
  final Dio dio;
  final String eventId;

  const _MembersSheet({required this.dio, required this.eventId});

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await widget.dio
        .get('/events/members', queryParameters: {'id': widget.eventId});
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    const statusLabels = {
      'go': ('Идёт', AppColors.success),
      'think': ('Думает', AppColors.secondary),
      'decline': ('Не идёт', AppColors.error),
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Участники',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snap.hasError) {
                  return const Center(
                    child: Text('Не удалось загрузить участников',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final members = snap.data!;
                if (members.isEmpty) {
                  return const Center(
                    child: Text('Пока никто не записался',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: members.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: AppColors.glassBorder,
                  ),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final username = m['username'] as String;
                    final status = m['status'] as String;
                    final (label, color) =
                        statusLabels[status] ?? ('Участник', AppColors.primary);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        child: Text(
                          username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text('@$username',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
