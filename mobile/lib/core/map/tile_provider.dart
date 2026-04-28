import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';

/// 2GIS tile URL (только подключаем — ключ берётся из --dart-define DGIS_API_KEY).
const _dgisApiKey = String.fromEnvironment('DGIS_API_KEY');
const dgisTileUrlTemplate =
    'https://tile2.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1&r=g&ts=online_sd&key=$_dgisApiKey';

/// Глобальный Dio для кеша тайлов. Кеш — in-memory, lifetime до перезапуска.
/// Для дискового кеша подключи `flutter_map_cache` с `CacheStore` (hive/path).
final _tileDio = Dio();

/// Готовый TileLayer с in-memory кешем — экономит трафик и тайлы рисуются мгновенно
/// при возврате к уже посещённым координатам.
TileLayer dgisTileLayer() => TileLayer(
      urlTemplate: dgisTileUrlTemplate,
      userAgentPackageName: 'com.eventmap.event_map',
      maxZoom: 19,
      tileProvider: CachedTileProvider(
        store: MemCacheStore(),
        dio: _tileDio,
      ),
    );
