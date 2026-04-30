import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/snackbar.dart';
import '../../../core/theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/auth/repository/auth_repository.dart';
import '../../../features/event/screens/my_events_screen.dart';
import '../repository/user_repository.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Профиль'),
        actions: [
          meAsync.maybeWhen(
            data: (user) => IconButton(
              icon: const Icon(Icons.edit_rounded,
                  color: AppColors.primary, size: 20),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EditProfileScreen(user: user),
                ));
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: meAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ошибка загрузки профиля',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => ref.read(authProvider.notifier).logout(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 32),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text('Выйти',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          data: (user) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 16),
              // Аватар
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2),
                  ),
                  child: ClipOval(
                    child: user.avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _avatarFallback(user.username),
                            errorWidget: (_, __, ___) =>
                                _avatarFallback(user.username),
                          )
                        : Center(
                            child: Text(
                              user.username.isNotEmpty ? user.username.substring(0, 1).toUpperCase() : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Имя
              Center(
                child: Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (!user.emailVerified) ...[
                const SizedBox(height: 16),
                _EmailNotVerifiedBanner(),
              ],
              const SizedBox(height: 32),
              // Ранг
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(user.rankEmoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        user.rankLabel,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${user.rating.toInt()} очков',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Статистика
              Row(
                children: [
                  _statCard(context, label: 'Роль',
                      value: _roleLabel(user.role)),
                ],
              ),
              const SizedBox(height: 16),
              // Мои события
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const MyEventsScreen(),
                )),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_rounded,
                          color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text('Мои события',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Кнопка выйти
              GestureDetector(
                onTap: () => ref.read(authProvider.notifier).logout(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.redAccent, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Выйти',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Logout со всех устройств — для случая «потерял телефон».
              GestureDetector(
                onTap: () => _confirmLogoutAll(context, ref),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Выйти со всех устройств',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogoutAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Выйти со всех устройств?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Все активные сессии будут завершены. Тебе придётся войти заново на каждом устройстве.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.textHint)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logoutAll();
    }
  }

  Widget _statCard(BuildContext context,
      {required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String username) => Center(
        child: Text(
          username.isNotEmpty ? username.substring(0, 1).toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 40,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Админ';
      case 'organizer':
        return 'Организатор';
      default:
        return 'Участник';
    }
  }
}

/// Баннер «Email не подтверждён» с кнопкой повторной отправки.
/// Показывается только когда `user.emailVerified == false`.
class _EmailNotVerifiedBanner extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EmailNotVerifiedBanner> createState() =>
      _EmailNotVerifiedBannerState();
}

class _EmailNotVerifiedBannerState
    extends ConsumerState<_EmailNotVerifiedBanner> {
  bool _loading = false;
  bool _sent = false;

  Future<void> _resend() async {
    if (_loading || _sent) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (mounted) {
        setState(() => _sent = true);
        context.showSuccess('Письмо отправлено. Проверь почту.');
      }
    } on AuthException catch (e) {
      if (mounted) context.showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB347);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: amber, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Email не подтверждён',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Подтверди email из письма',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _sent || _loading ? null : _resend,
            style: TextButton.styleFrom(
              foregroundColor: amber,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: amber),
                  )
                : Text(
                    _sent ? 'Отправлено' : 'Отправить',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
