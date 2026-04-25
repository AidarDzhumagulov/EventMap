import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../models/category_model.dart';
import '../../../models/event_model.dart';
import '../../map/providers/events_provider.dart';
import '../../map/repository/event_repository.dart';
import '../../map/widgets/category_picker.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final EventModel event;

  const EditEventScreen({super.key, required this.event});

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _maxMembersController;

  late DateTime _startTime;
  late bool _isPrivate;
  bool _isLoading = false;
  CategoryModel? _selectedCategory;
  File? _coverImage;
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e.title);
    _descController = TextEditingController(text: e.description);
    _maxMembersController =
        TextEditingController(text: e.maxMembers?.toString() ?? '');
    _startTime = e.startTime;
    _isPrivate = e.isPrivate;
    _coverUrl = e.coverUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return;

    setState(() {
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final maxMembers = _maxMembersController.text.isNotEmpty
          ? int.tryParse(_maxMembersController.text)
          : null;

      final repo = ref.read(eventRepositoryProvider);
      if (_coverImage != null) {
        _coverUrl = await repo.uploadCover(_coverImage!.path);
      }

      final updated = await repo.updateEvent(
            id: widget.event.id,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            coverUrl: _coverUrl,
            startTime: _startTime,
            isPrivate: _isPrivate,
            maxMembers: maxMembers,
            categoryId: _selectedCategory?.id ?? widget.event.categoryId,
          );

      ref.invalidate(eventsProvider(widget.event.cityName));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Событие обновлено'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ));
        // Возвращаем обновлённое событие обратно в EventDetailScreen
        Navigator.of(context).pop(updated);
      }
    } catch (e) {
      // Ловим и Exception и Error
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Ошибка',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text(
              e.toString(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Редактировать'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Сохранить',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildCoverPicker(),
            const SizedBox(height: 20),
            _buildField(
              label: 'Название *',
              child: TextFormField(
                controller: _titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Например: Джазовый вечер'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Обязательное поле' : null,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Описание',
              child: TextFormField(
                controller: _descController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Расскажи о событии...'),
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Категория',
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => CategoryPicker(
                    selectedId: _selectedCategory?.id ?? widget.event.categoryId,
                    onSelected: (cat) =>
                        setState(() => _selectedCategory = cat),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCategory?.nameRu ?? 'Категория без изменений',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textHint, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Дата и время начала *',
              child: GestureDetector(
                onTap: _pickStartTime,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('d MMM yyyy, HH:mm', 'ru')
                            .format(_startTime),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Макс. участников',
              child: TextFormField(
                controller: _maxMembersController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Не ограничено'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Закрытое событие',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 15),
                ),
                subtitle: const Text(
                  'Только по приглашению',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
                value: _isPrivate,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final hasImage = _coverImage != null || _coverUrl != null;
    return GestureDetector(
      onTap: () async {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1200,
        );
        if (picked != null) setState(() => _coverImage = File(picked.path));
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
          image: _coverImage != null
              ? DecorationImage(
                  image: FileImage(_coverImage!),
                  fit: BoxFit.cover,
                )
              : _coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
        ),
        child: !hasImage
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.textHint, size: 36),
                  const SizedBox(height: 8),
                  const Text('Добавить обложку',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 13)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _coverImage = null;
                      _coverUrl = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textHint, fontSize: 15),
      filled: true,
      fillColor: AppColors.surfaceVariant,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
