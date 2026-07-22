class RiderStats {
  const RiderStats({
    required this.ridesCount,
    required this.distanceMeters,
    required this.weekRidesCount,
    required this.weekDistanceMeters,
  });

  final int ridesCount;
  final int distanceMeters;
  final int weekRidesCount;
  final int weekDistanceMeters;

  double get distanceKm => distanceMeters / 1000;
  double get weekDistanceKm => weekDistanceMeters / 1000;

  factory RiderStats.fromJson(Map<String, dynamic> json) {
    return RiderStats(
      ridesCount: json['rides_count'] as int,
      distanceMeters: json['distance_meters'] as int,
      weekRidesCount: json['week_rides_count'] as int,
      weekDistanceMeters: json['week_distance_meters'] as int,
    );
  }
}
