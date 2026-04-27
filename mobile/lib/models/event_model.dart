import 'package:latlong2/latlong.dart';

import 'category_model.dart';

enum EventPrivacy { public, private }

enum EventStatus { upcoming, ongoing, finished }

class EventModel {
  final String id;
  final String title;
  final String description;
  final LatLng location;
  final String cityName;
  final DateTime startTime;
  final DateTime? endTime;
  final String createdBy;
  final String? creatorAvatarUrl;
  final String? coverUrl;
  final String? locationAddress;
  final EventPrivacy privacy;
  final EventStatus status;
  final int membersCount;
  final int? maxMembers;
  final int? categoryId;
  final String category;
  final String categoryEmoji;
  final String? categoryAlias;
  final String? inviteCode;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.cityName,
    required this.startTime,
    this.endTime,
    required this.createdBy,
    this.creatorAvatarUrl,
    this.coverUrl,
    this.locationAddress,
    required this.privacy,
    required this.status,
    required this.membersCount,
    this.maxMembers,
    this.categoryId,
    required this.category,
    required this.categoryEmoji,
    this.categoryAlias,
    this.inviteCode,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lon'] as num).toDouble(),
      ),
      cityName: json['city_name'] as String,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String).toLocal()
          : null,
      coverUrl: json['cover_url'] as String?,
      locationAddress: json['location_address'] as String?,
      privacy: (json['is_private'] as bool)
          ? EventPrivacy.private
          : EventPrivacy.public,
      status: _parseStatus(json['status'] as String? ?? 'upcoming'),
      maxMembers: json['max_members'] as int?,
      categoryId: json['category_id'] as int?,
      createdBy: json['created_by'] as String,
      membersCount: (json['members_count'] as int?) ?? 0,
      category: json['category_name'] as String? ?? '',
      categoryEmoji: categoryEmojiMap[json['category_alias'] as String?] ?? '📍',
      categoryAlias: json['category_alias'] as String?,
      inviteCode: json['invite_code'] as String?,
    );
  }

  static EventStatus _parseStatus(String s) {
    switch (s) {
      case 'ongoing':
        return EventStatus.ongoing;
      case 'finished':
        return EventStatus.finished;
      default:
        return EventStatus.upcoming;
    }
  }

  EventModel copyWith({int? membersCount}) {
    return EventModel(
      id: id,
      title: title,
      description: description,
      location: location,
      cityName: cityName,
      startTime: startTime,
      endTime: endTime,
      createdBy: createdBy,
      creatorAvatarUrl: creatorAvatarUrl,
      coverUrl: coverUrl,
      locationAddress: locationAddress,
      privacy: privacy,
      status: status,
      membersCount: membersCount ?? this.membersCount,
      maxMembers: maxMembers,
      categoryId: categoryId,
      category: category,
      categoryEmoji: categoryEmoji,
      categoryAlias: categoryAlias,
      inviteCode: inviteCode,
    );
  }

  bool get isPrivate => privacy == EventPrivacy.private;
  bool get isFull => maxMembers != null && membersCount >= maxMembers!;

  String get timeLabel {
    final now = DateTime.now();
    final diff = startTime.difference(now);
    if (diff.isNegative) return 'Идёт сейчас';
    if (diff.inDays > 0) return 'Через ${diff.inDays} дн.';
    if (diff.inHours > 0) return 'Через ${diff.inHours} ч.';
    return 'Скоро';
  }
}
