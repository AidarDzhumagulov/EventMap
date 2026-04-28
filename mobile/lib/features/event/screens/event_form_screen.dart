import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/snackbar.dart';
import '../../../core/theme.dart';
import '../../../models/category_model.dart';
import '../../../models/event_model.dart';
import '../../../models/location_model.dart';
import '../../map/providers/events_provider.dart';
import '../../map/repository/event_repository.dart';
import '../../map/repository/location_repository.dart';
import '../../map/screens/location_picker_screen.dart';
import '../../map/widgets/category_picker.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  /// null → режим создания, non-null → режим редактирования
  final EventModel? event;

  // Нужны только в режиме создания
  final double? initialLat;
  final double? initialLon;
  final String? initialCity;

  const EventFormScreen({
    super.key,
    this.event,
    this.initialLat,
    this.initialLon,
    this.initialCity,
  });

  bool get isEdit => event != null;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _maxMembersController;

  DateTime? _startTime;
  late bool _isPrivate;
  bool _isLoading = false;
  CategoryModel? _selectedCategory;
  File? _coverImage;
  String? _coverUrl; // существующая обложка (только в edit-режиме)

  // Только для режима создания
  late PickedLocation _pickedLocation;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _maxMembersController =
        TextEditingController(text: e?.maxMembers?.toString() ?? '');
    _startTime = e?.startTime;
    _isPrivate = e?.isPrivate ?? false;
    _coverUrl = e?.coverUrl;

    if (!widget.isEdit) {
      _pickedLocation = PickedLocation(
        lat: widget.initialLat!,
        lon: widget.initialLon!,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? now.add(const Duration(hours: 1)),
      firstDate: widget.isEdit ? DateTime(2020) : now,
      lastDate: now.add(const Duration(days: 365)),
      builder: _datePickerTheme,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _startTime != null
          ? TimeOfDay.fromDateTime(_startTime!)
          : TimeOfDay.now(),
      builder: _datePickerTheme,
    );
    if (time == null) return;

    setState(() {
      _startTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget Function(BuildContext, Widget?) get _datePickerTheme =>
      (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surface,
              ),
            ),
            child: child!,
          );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null) {
      context.showError('Укажи дату и время начала');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(eventRepositoryProvider);
      final maxMembers = _maxMembersController.text.isNotEmpty
          ? int.tryParse(_maxMembersController.text)
          : null;

      if (_coverImage != null) {
        _coverUrl = await repo.uploadCover(_coverImage!.path);
      }

      if (widget.isEdit) {
        final updated = await repo.updateEvent(
          id: widget.event!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          coverUrl: _coverUrl,
          startTime: _startTime!,
          isPrivate: _isPrivate,
          maxMembers: maxMembers,
          categoryId: _selectedCategory?.id ?? widget.event!.categoryId,
        );
        ref.invalidate(eventsProvider(widget.event!.cityName));
        if (mounted) {
          context.showSuccess('Событие обновлено');
          Navigator.of(context).pop(updated);
        }
      } else {
        final locationRepo = ref.read(locationRepositoryProvider);
        final location = await locationRepo.createLocation(
          lat: _pickedLocation.lat,
          lon: _pickedLocation.lon,
          address: _pickedLocation.address,
        );
        await repo.createEvent(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          coverUrl: _coverUrl,
          lat: _pickedLocation.lat,
          lon: _pickedLocation.lon,
          cityName: widget.initialCity!,
          startTime: _startTime!,
          isPrivate: _isPrivate,
          maxMembers: maxMembers,
          categoryId: _selectedCategory?.id,
          locationId: location.id,
        );
        ref.invalidate(eventsProvider(widget.initialCity!));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Ошибка',
                style: TextStyle(color: AppColors.textPrimary)),
            content: Text(e.toString(),
                style: const TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child:
                    const Text('OK', style: TextStyle(color: AppColors.primary)),
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
        title: Text(widget.isEdit ? 'Редактировать' : 'Новое событие'),
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
                          strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      widget.isEdit ? 'Сохранить' : 'Создать',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
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
              child: _buildCategoryPicker(),
            ),
            const SizedBox(height: 16),
            _buildField(
              label: 'Дата и время начала *',
              child: _buildDateTimePicker(),
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
            _buildPrivacyToggle(),
            if (!widget.isEdit) ...[
              const SizedBox(height: 24),
              _buildField(
                label: 'Место проведения *',
                child: _buildLocationPicker(),
              ),
            ],
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
        if (picked != null && mounted) {
          setState(() => _coverImage = File(picked.path));
        }
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
          image: _coverImage != null
              ? DecorationImage(
                  image: FileImage(_coverImage!), fit: BoxFit.cover)
              : _coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_coverUrl!), fit: BoxFit.cover)
                  : null,
        ),
        child: !hasImage
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      color: AppColors.textHint, size: 36),
                  SizedBox(height: 8),
                  Text('Добавить обложку',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 13)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() {
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

  Widget _buildCategoryPicker() {
    final label = _selectedCategory?.nameRu ??
        (widget.isEdit ? 'Категория без изменений' : 'Выбрать категорию');
    final hasValue = _selectedCategory != null;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => CategoryPicker(
          selectedId: _selectedCategory?.id ?? widget.event?.categoryId,
          onSelected: (cat) => setState(() => _selectedCategory = cat),
        ),
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                label,
                style: TextStyle(
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return GestureDetector(
      onTap: _pickStartTime,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              _startTime != null
                  ? DateFormat('d MMM yyyy, HH:mm', 'ru')
                      .format(_startTime!)
                  : 'Выбрать дату и время',
              style: TextStyle(
                color: _startTime != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Закрытое событие',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        subtitle: const Text('Только по приглашению',
            style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        value: _isPrivate,
        activeThumbColor: AppColors.primary,
        onChanged: (v) => setState(() => _isPrivate = v),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return GestureDetector(
      onTap: () async {
        final result =
            await Navigator.of(context).push<PickedLocation>(
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              initialCenter:
                  LatLng(_pickedLocation.lat, _pickedLocation.lon),
            ),
          ),
        );
        if (result != null && mounted) {
          setState(() => _pickedLocation = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _pickedLocation.address != null
                    ? '${widget.initialCity} · ${_pickedLocation.address}'
                    : '${widget.initialCity} · ${_pickedLocation.lat.toStringAsFixed(4)}, ${_pickedLocation.lon.toStringAsFixed(4)}',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
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
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
