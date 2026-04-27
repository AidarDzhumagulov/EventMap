import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/category_model.dart';
import '../../../models/location_model.dart';
import '../providers/events_provider.dart';
import '../repository/event_repository.dart';
import '../repository/location_repository.dart';
import '../widgets/category_picker.dart';
import 'location_picker_screen.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  final double initialLat;
  final double initialLon;
  final String initialCity;

  const CreateEventScreen({
    super.key,
    required this.initialLat,
    required this.initialLon,
    required this.initialCity,
  });

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _maxMembersController = TextEditingController();

  DateTime? _startTime;
  bool _isPrivate = false;
  bool _isLoading = false;
  late PickedLocation _pickedLocation;
  CategoryModel? _selectedCategory;
  File? _coverImage;

  @override
  void initState() {
    super.initState();
    _pickedLocation = PickedLocation(
      lat: widget.initialLat,
      lon: widget.initialLon,
    );
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
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
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
      initialTime: TimeOfDay.now(),
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
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажи дату и время начала')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final maxMembers = _maxMembersController.text.isNotEmpty
          ? int.tryParse(_maxMembersController.text)
          : null;

      final repo = ref.read(eventRepositoryProvider);
      final locationRepo = ref.read(locationRepositoryProvider);

      String? coverUrl;
      if (_coverImage != null) {
        coverUrl = await repo.uploadCover(_coverImage!.path);
      }

      final location = await locationRepo.createLocation(
        lat: _pickedLocation.lat,
        lon: _pickedLocation.lon,
        address: _pickedLocation.address,
      );

      await repo.createEvent(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            coverUrl: coverUrl,
            lat: _pickedLocation.lat,
            lon: _pickedLocation.lon,
            cityName: widget.initialCity,
            startTime: _startTime!,
            isPrivate: _isPrivate,
            maxMembers: maxMembers,
            categoryId: _selectedCategory?.id,
            locationId: location.id,
          );

      // Обновляем список событий на карте
      ref.invalidate(eventsProvider(widget.initialCity));

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        await showDialog(
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
        title: const Text('Новое событие'),
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
                      'Создать',
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
                    selectedId: _selectedCategory?.id,
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
                          _selectedCategory?.nameRu ?? 'Выбрать категорию',
                          style: TextStyle(
                            color: _selectedCategory != null
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
                  style: TextStyle(
                      color: AppColors.textHint, fontSize: 12),
                ),
                value: _isPrivate,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ),
            const SizedBox(height: 24),
            _buildField(
              label: 'Место проведения *',
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(context).push<PickedLocation>(
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        initialCenter: LatLng(
                            _pickedLocation.lat, _pickedLocation.lon),
                      ),
                    ),
                  );
                  if (result != null) {
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
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
              : null,
        ),
        child: _coverImage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
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
                    onTap: () => setState(() => _coverImage = null),
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
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
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
