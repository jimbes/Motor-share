class BikePhoto {
  const BikePhoto({required this.id, required this.url});

  final int id;
  final String url;

  factory BikePhoto.fromJson(Map<String, dynamic> json) {
    return BikePhoto(id: json['id'] as int, url: json['url'] as String);
  }
}
