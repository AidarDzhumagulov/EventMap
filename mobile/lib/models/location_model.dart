class LocationModel {
  final String id;
  final double lat;
  final double lon;
  final String? address;
  final String? name;

  const LocationModel({
    required this.id,
    required this.lat,
    required this.lon,
    this.address,
    this.name,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        id: json['id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        address: json['address'] as String?,
        name: json['name'] as String?,
      );
}

class PickedLocation {
  final double lat;
  final double lon;
  final String? address;

  const PickedLocation({required this.lat, required this.lon, this.address});
}
