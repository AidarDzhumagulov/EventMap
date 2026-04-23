import 'package:latlong2/latlong.dart';

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
  final String creatorUsername;
  final String? creatorAvatarUrl;
  final String? coverUrl;
  final EventPrivacy privacy;
  final EventStatus status;
  final int membersCount;
  final int? maxMembers;
  final String category;
  final String categoryEmoji;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.cityName,
    required this.startTime,
    this.endTime,
    required this.creatorUsername,
    this.creatorAvatarUrl,
    this.coverUrl,
    required this.privacy,
    required this.status,
    required this.membersCount,
    this.maxMembers,
    required this.category,
    required this.categoryEmoji,
  });

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
