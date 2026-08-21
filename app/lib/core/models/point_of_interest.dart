import 'user_summary.dart';

/// A point of interest added live during a ride (REDL project doc, section
/// 9.4). Visible on the community map from the moment it's created,
/// regardless of whether its ride ends up published.
class PointOfInterest {
  const PointOfInterest({
    required this.id,
    this.title,
    required this.lat,
    required this.lng,
    this.photoUrl,
    required this.createdAt,
    required this.user,
    required this.rideId,
    required this.ridePublished,
  });

  final int id;
  final String? title;
  final double lat;
  final double lng;
  final String? photoUrl;
  final DateTime createdAt;
  final UserSummary user;
  final int rideId;
  final bool ridePublished;

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'] as int,
      title: json['title'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      rideId: json['ride_id'] as int,
      ridePublished: json['ride_published'] as bool,
    );
  }
}

/// The lightweight POI shape embedded directly on a ride's own detail
/// response (`points_of_interest`) - unlike [PointOfInterest] (from the
/// community map endpoints), it has no author/date since it's implicitly
/// this ride's own author.
class RidePointOfInterest {
  const RidePointOfInterest({
    required this.id,
    this.title,
    required this.lat,
    required this.lng,
    this.photoUrl,
  });

  final int id;
  final String? title;
  final double lat;
  final double lng;
  final String? photoUrl;

  factory RidePointOfInterest.fromJson(Map<String, dynamic> json) {
    return RidePointOfInterest(
      id: json['id'] as int,
      title: json['title'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      photoUrl: json['photo_url'] as String?,
    );
  }
}
