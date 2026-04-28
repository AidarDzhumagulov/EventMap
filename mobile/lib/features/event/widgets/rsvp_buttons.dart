import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/snackbar.dart';
import '../../../core/theme.dart';
import '../../map/providers/events_provider.dart';

/// Кнопки RSVP: Иду / Подумаю / Не пойду.
///
/// Загружает текущий статус сам. При изменении вызывает [onStatusChanged]
/// с (oldStatus, newStatus) — используется для обновления счётчика участников.
class RsvpButtons extends ConsumerStatefulWidget {
  final String eventId;
  final String cityName;
  final bool isFull;
  final void Function(String? oldStatus, String? newStatus)? onStatusChanged;

  const RsvpButtons({
    super.key,
    required this.eventId,
    required this.cityName,
    required this.isFull,
    this.onStatusChanged,
  });

  @override
  ConsumerState<RsvpButtons> createState() => _RsvpButtonsState();
}

class _RsvpButtonsState extends ConsumerState<RsvpButtons> {
  String? _status; // 'go' | 'think' | 'decline' | null
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  @override
  void didUpdateWidget(RsvpButtons old) {
    super.didUpdateWidget(old);
    if (old.eventId != widget.eventId) {
      _status = null;
      _fetchStatus();
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio
          .get('/events/my-status', queryParameters: {'id': widget.eventId});
      if (mounted && res.statusCode == 200) {
        setState(() {
          _status = (res.data as Map<String, dynamic>)['status'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _onTap(String tapped) async {
    if (_loading) return;
    setState(() => _loading = true);

    final oldStatus = _status;
    try {
      final dio = ref.read(dioClientProvider);
      if (_status == tapped) {
        // повторный тап — отменяем участие
        await dio.delete('/events/leave',
            queryParameters: {'id': widget.eventId});
        if (mounted) setState(() => _status = null);
        widget.onStatusChanged?.call(oldStatus, null);
      } else {
        await dio.post('/events/join',
            queryParameters: {'id': widget.eventId, 'status': tapped});
        if (mounted) setState(() => _status = tapped);
        widget.onStatusChanged?.call(oldStatus, tapped);
      }
      ref.invalidate(eventsProvider(widget.cityName));
    } catch (e) {
      if (mounted) context.showApiError(e, fallback: 'Не удалось обновить статус');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFull && _status != 'go') {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: const Center(
          child: Text('Мест нет',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _MainBtn(
            label: '✓  Иду',
            active: _status == 'go',
            loading: _loading,
            onTap: () => _onTap('go'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _IconBtn(
            icon: Icons.help_outline_rounded,
            tooltip: 'Подумаю',
            active: _status == 'think',
            activeColor: Colors.amber,
            loading: _loading,
            onTap: () => _onTap('think'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _IconBtn(
            icon: Icons.close_rounded,
            tooltip: 'Не пойду',
            active: _status == 'decline',
            activeColor: AppColors.error,
            loading: _loading,
            onTap: () => _onTap('decline'),
          ),
        ),
      ],
    );
  }
}

class _MainBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  const _MainBtn({
    required this.label,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.glassBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.glassBorder),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1)
                ]
              : [],
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: active ? Colors.white : AppColors.primary))
              : Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final bool loading;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.activeColor,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active
                    ? activeColor.withValues(alpha: 0.5)
                    : AppColors.glassBorder),
          ),
          child: Icon(icon,
              color: active ? activeColor : AppColors.textSecondary, size: 20),
        ),
      ),
    );
  }
}
