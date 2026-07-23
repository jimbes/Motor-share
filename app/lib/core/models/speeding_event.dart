/// A single continuous stretch of a ride spent above the posted speed
/// limit (plus tolerance), as computed server-side from OpenStreetMap
/// road data.
class SpeedingEvent {
  const SpeedingEvent({
    required this.startedAt,
    required this.durationSeconds,
    required this.limitKmh,
    required this.maxSpeedKmh,
    required this.excessKmh,
  });

  final DateTime startedAt;
  final int durationSeconds;
  final double limitKmh;
  final double maxSpeedKmh;
  final double excessKmh;

  factory SpeedingEvent.fromJson(Map<String, dynamic> json) {
    return SpeedingEvent(
      startedAt: DateTime.parse(json['started_at'] as String),
      durationSeconds: json['duration_seconds'] as int,
      limitKmh: double.parse(json['limit_kmh'].toString()),
      maxSpeedKmh: double.parse(json['max_speed_kmh'].toString()),
      excessKmh: double.parse(json['excess_kmh'].toString()),
    );
  }
}
