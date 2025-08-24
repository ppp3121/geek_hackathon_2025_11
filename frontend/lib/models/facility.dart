class Facility {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final String category;
  final double? distance;

  const Facility({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.category,
    this.distance,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as int,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      category: json['category'] as String,
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'category': category,
      'distance': distance,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Facility && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Facility(id: $id, name: $name, lat: $lat, lon: $lon, category: $category, distance: $distance)';
  }
}