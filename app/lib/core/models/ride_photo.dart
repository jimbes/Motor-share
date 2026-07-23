class RidePhoto {
  const RidePhoto({required this.id, required this.url, this.lat, this.lng});

  final int id;
  final String url;
  final double? lat;
  final double? lng;

  factory RidePhoto.fromJson(Map<String, dynamic> json) {
    return RidePhoto(
      id: json['id'] as int,
      url: json['url'] as String,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
