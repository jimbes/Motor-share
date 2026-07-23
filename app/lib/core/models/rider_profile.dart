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
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
  });

  final int id;
  final String name;
  final String username;
  final String? avatarUrl;
  final DateTime memberSince;
  final int ridesCount;
  final int distanceMeters;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;

  double get distanceKm => distanceMeters / 1000;

  RiderProfile copyWith({bool? isFollowing, int? followersCount}) {
    return RiderProfile(
      id: id,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      memberSince: memberSince,
      ridesCount: ridesCount,
      distanceMeters: distanceMeters,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      id: json['id'] as int,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      memberSince: DateTime.parse(json['member_since'] as String),
      ridesCount: json['rides_count'] as int,
      distanceMeters: json['distance_meters'] as int,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
    );
  }
}
