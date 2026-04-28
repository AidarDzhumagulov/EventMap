import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/event_model.dart';

class EventRepository {
  final Dio _dio;

  const EventRepository(this._dio);

  Future<List<EventModel>> getEvents({
    String city = '',
    String search = '',
    int limit = 100,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/events',
      queryParameters: {
        if (city.isNotEmpty) 'city': city,
        if (search.isNotEmpty) 'search': search,
        'limit': limit,
        'offset': offset,
      },
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EventModel> getEvent(String id) async {
    final response =
        await _dio.get('/events/detail', queryParameters: {'id': id});
    return EventModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Стопка событий для свайп-ленты. Бэк фильтрует анти-повтор —
  /// события, с которыми юзер уже взаимодействовал, не возвращаются.
  Future<List<EventModel>> getFeed({
    required String city,
    int limit = 40,
  }) async {
    final response = await _dio.get(
      '/events/feed',
      queryParameters: {'city': city, 'limit': limit},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Записывает скип события — чтобы оно больше не попадалось в свайп-ленте.
  Future<void> markSkipped(String eventId) async {
    await _dio.post('/events/skip', queryParameters: {'id': eventId});
  }

  Future<String> uploadCover(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/upload',
      queryParameters: {'type': 'cover'},
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }

  Future<EventModel> createEvent({
    required String title,
    String? description,
    String? coverUrl,
    required double lat,
    required double lon,
    required String cityName,
    required DateTime startTime,
    DateTime? endTime,
    bool isPrivate = false,
    int? maxMembers,
    int? categoryId,
    String? locationId,
  }) async {
    final response = await _dio.post('/events/create', data: {
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (coverUrl != null) 'cover_url': coverUrl,
      'lat': lat,
      'lon': lon,
      'city_name': cityName,
      'start_time': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
      'is_private': isPrivate,
      if (maxMembers != null) 'max_members': maxMembers,
      if (categoryId != null) 'category_id': categoryId,
      if (locationId != null) 'location_id': locationId,
    });
    return EventModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<EventModel> updateEvent({
    required String id,
    required String title,
    String? description,
    String? coverUrl,
    required DateTime startTime,
    DateTime? endTime,
    bool isPrivate = false,
    int? maxMembers,
    int? categoryId,
  }) async {
    final response = await _dio.put(
      '/events/update',
      queryParameters: {'id': id},
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (coverUrl != null) 'cover_url': coverUrl,
        'start_time': startTime.toUtc().toIso8601String(),
        if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
        'is_private': isPrivate,
        if (maxMembers != null) 'max_members': maxMembers,
        if (categoryId != null) 'category_id': categoryId,
      },
    );
    return EventModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.read(dioClientProvider));
});
