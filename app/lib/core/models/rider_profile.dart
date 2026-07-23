/// A rider's public profile - GET /users/{username}.
class RiderProfile {
  const RiderProfile({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.memberSince,
    required this.ridesCount,
    required this.distanceMeters,
  });

  final int id;
  final String name;
  final String username;
  final String? avatarUrl;
  final DateTime memberSince;
  final int ridesCount;
  final int distanceMeters;

  double get distanceKm => distanceMeters / 1000;

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      memberSince: DateTime.parse(json['member_since'] as String),
      ridesCount: json['rides_count'] as int,
      distanceMeters: json['distance_meters'] as int,
    );
  }
}
