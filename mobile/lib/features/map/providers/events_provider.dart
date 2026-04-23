import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../models/event_model.dart';

// Mock события — Бишкек и Алматы
final _mockEvents = [
  EventModel(
    id: '1',
    title: 'Вечеринка на крыше',
    description: 'Закрытая тусовка с живой музыкой, коктейлями и крутым видом на город. Только для своих.',
    location: LatLng(42.8746, 74.5698),
    cityName: 'Бишкек',
    startTime: DateTime.now().add(const Duration(hours: 3)),
    creatorUsername: 'aidar_b',
    privacy: EventPrivacy.private,
    status: EventStatus.upcoming,
    membersCount: 18,
    maxMembers: 30,
    category: 'Вечеринка',
    categoryEmoji: '🎉',
  ),
  EventModel(
    id: '2',
    title: 'Скейт-сессия Дубовый парк',
    description: 'Собираемся у главного входа, катаем до темноты. Все уровни welcome.',
    location: LatLng(42.8700, 74.5900),
    cityName: 'Бишкек',
    startTime: DateTime.now().add(const Duration(hours: 1)),
    creatorUsername: 'skate_kg',
    privacy: EventPrivacy.public,
    status: EventStatus.upcoming,
    membersCount: 7,
    category: 'Спорт',
    categoryEmoji: '🛹',
  ),
  EventModel(
    id: '3',
    title: 'Джаз в подвале',
    description: 'Квартет играет стандарты — Coltrane, Miles Davis, Monk. Вход свободный.',
    location: LatLng(42.8760, 74.5750),
    cityName: 'Бишкек',
    startTime: DateTime.now().subtract(const Duration(minutes: 20)),
    creatorUsername: 'jazz_bishkek',
    privacy: EventPrivacy.public,
    status: EventStatus.ongoing,
    membersCount: 45,
    category: 'Музыка',
    categoryEmoji: '🎷',
  ),
  EventModel(
    id: '4',
    title: 'Нетворкинг IT Алматы',
    description: 'Встреча разработчиков, дизайнеров и продактов. Питч-сессия + свободное общение.',
    location: LatLng(43.2220, 76.8512),
    cityName: 'Алматы',
    startTime: DateTime.now().add(const Duration(days: 1, hours: 2)),
    creatorUsername: 'tech_almaty',
    privacy: EventPrivacy.public,
    status: EventStatus.upcoming,
    membersCount: 62,
    maxMembers: 100,
    category: 'IT',
    categoryEmoji: '💻',
  ),
  EventModel(
    id: '5',
    title: 'Пикник у Медеу',
    description: 'Берём еду, пледы и хорошее настроение. Место встречи — парковка катка.',
    location: LatLng(43.1500, 77.0200),
    cityName: 'Алматы',
    startTime: DateTime.now().add(const Duration(hours: 5)),
    creatorUsername: 'almaty_vibes',
    privacy: EventPrivacy.public,
    status: EventStatus.upcoming,
    membersCount: 23,
    category: 'Отдых',
    categoryEmoji: '🧺',
  ),
  EventModel(
    id: '6',
    title: 'Закрытый ужин',
    description: 'Дегустационное меню от шеф-повара. 8 персон, только по приглашению.',
    location: LatLng(43.2365, 76.9286),
    cityName: 'Алматы',
    startTime: DateTime.now().add(const Duration(hours: 6)),
    creatorUsername: 'chef_ali',
    privacy: EventPrivacy.private,
    status: EventStatus.upcoming,
    membersCount: 5,
    maxMembers: 8,
    category: 'Еда',
    categoryEmoji: '🍽️',
  ),
];

final eventsProvider = Provider<List<EventModel>>((ref) => _mockEvents);

final selectedEventProvider = StateProvider<EventModel?>((ref) => null);

// Начальная позиция карты — Бишкек
final mapCenterProvider = StateProvider<LatLng>(
  (ref) => LatLng(42.8746, 74.5698),
);
