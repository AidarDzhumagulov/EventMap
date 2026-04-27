import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/location_model.dart';

class LocationRepository {
  final Dio _dio;

  const LocationRepository(this._dio);

  Future<LocationModel> createLocation({
    required double lat,
    required double lon,
    String? address,
    String? name,
  }) async {
    final response = await _dio.post('/locations/create', data: {
      'lat': lat,
      'lon': lon,
      if (address != null) 'address': address,
      if (name != null) 'name': name,
      'provider': 'nominatim',
    });
    return LocationModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(ref.read(dioClientProvider));
});
