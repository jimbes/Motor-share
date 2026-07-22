import 'ride_comment.dart';
import 'ride_photo.dart';
import 'track_point.dart';

class RideAuthor {
  const RideAuthor({required this.id, required this.name});

  final int id;
  final String name;

  factory RideAuthor.fromJson(Map<String, dynamic> json) {
    return RideAuthor(id: json['id'] as int, name: json['name'] as String);
  }
}

class RideBikeSummary {
  const RideBikeSummary({required this.id, required this.brand, required this.model, this.nickname});

  final int id;
  final String brand;
  final String model;
  final String? nickname;

  String get displayName => nickname?.isNotEmpty == true ? nickname! : '$brand $model';

  factory RideBikeSummary.fromJson(Map<String, dynamic> json) {
    return RideBikeSummary(
      id: json['id'] as int,
      brand: json['brand'] as String,
      model: json['model'] as String,
      nickname: json['nickname'] as String?,
    );
  }
}

/// A ride as returned by both the feed (`GET /rides`, no [track]) and the
/// detail endpoint (`GET /rides/{id}`, no [polyline] but full [track]).
class Ride {
  const Ride({
    required this.id,
    required this.title,
    this.description,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.user,
    this.bike,
    this.polyline = const [],
    this.track,
    this.photos = const [],
    this.comments,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
  });

  final int id;
  final String title;
  final String? description;
  final DateTime startedAt;
  final int durationSeconds;
  final int distanceMeters;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final RideAuthor user;
  final RideBikeSummary? bike;
  final List<TrackPoint> polyline;
  final List<TrackPoint>? track;
  final List<RidePhoto> photos;
  final List<RideComment>? comments;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;

  /// The route line to draw on a map: the full track when available
  /// (detail view), otherwise the lightweight simplified polyline (feed).
  List<TrackPoint> get routeLine => track ?? polyline;

  double get distanceKm => distanceMeters / 1000;

  Duration get duration => Duration(seconds: durationSeconds);

  Ride copyWith({int? likesCount, bool? likedByMe, List<RideComment>? comments, int? commentsCount}) {
    return Ride(
      id: id,
      title: title,
      description: description,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      user: user,
      bike: bike,
      polyline: polyline,
      track: track,
      photos: photos,
      comments: comments ?? this.comments,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      durationSeconds: json['duration_seconds'] as int,
      distanceMeters: json['distance_meters'] as int,
      avgSpeedKmh: double.parse(json['avg_speed_kmh'].toString()),
      maxSpeedKmh: double.parse(json['max_speed_kmh'].toString()),
      user: RideAuthor.fromJson(json['user'] as Map<String, dynamic>),
      bike: json['bike'] != null ? RideBikeSummary.fromJson(json['bike'] as Map<String, dynamic>) : null,
      polyline: (json['polyline'] as List<dynamic>? ?? [])
          .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      track: (json['track'] as List<dynamic>?)
          ?.map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => RidePhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      comments: (json['comments'] as List<dynamic>?)
          ?.map((e) => RideComment.fromJson(e as Map<String, dynamic>))
          .toList(),
      likesCount: json['likes_count'] as int,
      commentsCount: json['comments_count'] as int,
      likedByMe: json['liked_by_me'] as bool,
    );
  }
}
