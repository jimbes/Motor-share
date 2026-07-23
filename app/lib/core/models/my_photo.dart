/// A photo from `GET /me/photos` - one of the rider's own photos plus a
/// summary of the ride it was taken on, for the personal photo library
/// (grid + map).
class MyPhoto {
  const MyPhoto({
    required this.id,
    required this.url,
    this.lat,
    this.lng,
    required this.rideId,
    required this.rideTitle,
    required this.rideStartedAt,
  });

  final int id;
  final String url;
  final double? lat;
  final double? lng;
  final int rideId;
  final String rideTitle;
  final DateTime rideStartedAt;

  bool get hasLocation => lat != null && lng != null;

  factory MyPhoto.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] as Map<String, dynamic>;
    return MyPhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      rideId: ride['id'] as int,
      rideTitle: ride['title'] as String,
      rideStartedAt: DateTime.parse(ride['started_at'] as String),
    );
  }
}
