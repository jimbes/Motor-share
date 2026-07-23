import 'dart:io';

import 'package:dio/dio.dart';

import '../api_client.dart';
import '../models/my_photo.dart';
import '../models/ride.dart';
import '../models/ride_comment.dart';
import '../models/rider_stats.dart';
import '../models/track_point.dart';
import '../models/user_summary.dart';

class RideFeedPage {
  const RideFeedPage({required this.rides, required this.hasMorePages});

  final List<Ride> rides;
  final bool hasMorePages;
}

class MyPhotosPage {
  const MyPhotosPage({required this.photos, required this.hasMorePages});

  final List<MyPhoto> photos;
  final bool hasMorePages;
}

class RideRepository {
  RideRepository(this._client);

  final ApiClient _client;

  Future<RideFeedPage> feed({int page = 1, int? userId, String? scope}) async {
    final response = await _client.dio.get('/rides', queryParameters: {
      'page': page,
      if (userId != null) 'user_id': userId,
      if (scope != null) 'scope': scope,
    });
    final data = response.data as Map<String, dynamic>;
    final rides = (data['data'] as List<dynamic>).map((e) => Ride.fromJson(e as Map<String, dynamic>)).toList();
    final meta = data['meta'] as Map<String, dynamic>?;
    final currentPage = meta?['current_page'] as int? ?? page;
    final lastPage = meta?['last_page'] as int? ?? page;
    return RideFeedPage(rides: rides, hasMorePages: currentPage < lastPage);
  }

  Future<Ride> show(int id) async {
    final response = await _client.dio.get('/rides/$id');
    return Ride.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Ride> upload({
    int? bikeId,
    required String title,
    String? description,
    required DateTime startedAt,
    required int durationSeconds,
    required int distanceMeters,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
    required List<TrackPoint> track,
  }) async {
    final response = await _client.dio.post('/rides', data: {
      if (bikeId != null) 'bike_id': bikeId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'started_at': startedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'avg_speed_kmh': avgSpeedKmh,
      'max_speed_kmh': maxSpeedKmh,
      'track': track.map((p) => p.toJson()).toList(),
    });
    return Ride.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> uploadPhoto(int rideId, File photo, {double? lat, double? lng}) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(photo.path),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    await _client.dio.post('/rides/$rideId/photos', data: formData);
  }

  Future<MyPhotosPage> myPhotos({int page = 1}) async {
    final response = await _client.dio.get('/me/photos', queryParameters: {'page': page});
    final data = response.data as Map<String, dynamic>;
    final photos = (data['data'] as List<dynamic>).map((e) => MyPhoto.fromJson(e as Map<String, dynamic>)).toList();
    final meta = data['meta'] as Map<String, dynamic>?;
    final currentPage = meta?['current_page'] as int? ?? page;
    final lastPage = meta?['last_page'] as int? ?? page;
    return MyPhotosPage(photos: photos, hasMorePages: currentPage < lastPage);
  }

  Future<({int likesCount, bool likedByMe})> like(int rideId) async {
    final response = await _client.dio.post('/rides/$rideId/like');
    return (likesCount: response.data['likes_count'] as int, likedByMe: response.data['liked_by_me'] as bool);
  }

  Future<({int likesCount, bool likedByMe})> unlike(int rideId) async {
    final response = await _client.dio.delete('/rides/$rideId/like');
    return (likesCount: response.data['likes_count'] as int, likedByMe: response.data['liked_by_me'] as bool);
  }

  Future<List<RideComment>> comments(int rideId) async {
    final response = await _client.dio.get('/rides/$rideId/comments');
    return (response.data as List<dynamic>).map((e) => RideComment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RideComment> addComment(int rideId, String body) async {
    final response = await _client.dio.post('/rides/$rideId/comments', data: {'body': body});
    return RideComment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteComment(int commentId) => _client.dio.delete('/comments/$commentId');

  Future<List<UserSummary>> addParticipant(int rideId, String username) async {
    final response = await _client.dio.post('/rides/$rideId/participants', data: {'username': username});
    return (response.data as List<dynamic>).map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserSummary>> removeParticipant(int rideId, int userId) async {
    final response = await _client.dio.delete('/rides/$rideId/participants/$userId');
    return (response.data as List<dynamic>).map((e) => UserSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<RiderStats> myStats() async {
    final response = await _client.dio.get('/me/stats');
    return RiderStats.fromJson(response.data as Map<String, dynamic>);
  }
}
