class RidePhoto {
  const RidePhoto({required this.id, required this.url});

  final int id;
  final String url;

  factory RidePhoto.fromJson(Map<String, dynamic> json) {
    return RidePhoto(id: json['id'] as int, url: json['url'] as String);
  }
}
