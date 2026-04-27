import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../models/location_model.dart';

class LocationPickerScreen extends StatefulWidget {
  final LatLng initialCenter;

  const LocationPickerScreen({super.key, required this.initialCenter});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _dgisApiKey = String.fromEnvironment('DGIS_API_KEY');
  static const _2gisTile =
      'https://tile2.maps.2gis.com/tiles?x={x}&y={y}&z={z}&v=1&r=g&ts=online_sd&key=$_dgisApiKey';

  late LatLng _picked;
  String? _address;
  bool _isGeocoding = false;
  Timer? _geocodeDebounce;

  final _geocodeDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  @override
  void initState() {
    super.initState();
    _picked = widget.initialCenter;
    _reverseGeocode(_picked);
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _geocodeDio.close();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isGeocoding = true);
    try {
      final response = await _geocodeDio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'json',
          'accept-language': 'ru',
          'zoom': 18,
        },
        options: Options(headers: {
          'User-Agent': 'EventMapApp/1.0',
        }),
      );
      final data = response.data as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr != null) {
        final amenity     = addr['amenity']      as String?;
        final building    = addr['building']     as String?;
        final road        = addr['road']         as String?
                         ?? addr['pedestrian']   as String?
                         ?? addr['path']         as String?;
        final houseNumber = addr['house_number'] as String?;
        final suburb      = addr['suburb']       as String?
                         ?? addr['neighbourhood'] as String?
                         ?? addr['quarter']      as String?;

        final parts = <String>[];

        if (amenity != null || building != null) {
          parts.add(amenity ?? building!);
        }

        if (road != null) {
          parts.add(houseNumber != null ? '$road, $houseNumber' : road);
        }

        if (houseNumber == null && suburb != null) {
          parts.add(suburb);
        }

        _address = parts.isNotEmpty
            ? parts.join(', ')
            : data['display_name'] as String?;
      }
    } catch (_) {
      _address = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось определить адрес'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _picked = point;
      _address = null;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(point);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Выбери место'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(
                PickedLocation(
                  lat: _picked.latitude,
                  lon: _picked.longitude,
                  address: _address,
                ),
              ),
              child: const Text(
                'Готово',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: 14,
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: _2gisTile,
                userAgentPackageName: 'com.eventmap.event_map',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: const Text(
                'Нажми на карту чтобы выбрать место',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isGeocoding
                        ? const Text(
                            'Определяем адрес...',
                            style: TextStyle(
                                color: AppColors.textHint, fontSize: 14),
                          )
                        : Text(
                            _address ??
                                '${_picked.latitude.toStringAsFixed(5)}, ${_picked.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                              color: _address != null
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
