class TrackPoint {
  const TrackPoint({required this.lat, required this.lng, this.alt, this.speed, this.t});

  final double lat;
  final double lng;
  final double? alt;
  final double? speed;
  final String? t;

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      alt: (json['alt'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      t: json['t'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (alt != null) 'alt': alt,
        if (speed != null) 'speed': speed,
        if (t != null) 't': t,
      };
}
