import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/models/bike.dart';
import 'package:redl/core/models/my_photo.dart';
import 'package:redl/core/models/ride.dart';
import 'package:redl/core/models/ride_photo.dart';
import 'package:redl/core/models/rider_profile.dart';
import 'package:redl/core/models/rider_stats.dart';
import 'package:redl/core/models/track_point.dart';
import 'package:redl/core/models/user.dart';
import 'package:redl/core/models/user_summary.dart';

void main() {
  group('TrackPoint', () {
    test('parses and round-trips through JSON', () {
      final point = TrackPoint.fromJson({'lat': 43.5, 'lng': 5.4, 'alt': 100.0, 'speed': 60.0, 't': '2026-01-01T00:00:00Z'});
      expect(point.lat, 43.5);
      expect(point.lng, 5.4);
      expect(point.toJson()['lat'], 43.5);
    });
  });

  group('Bike', () {
    test('displayName prefers nickname over brand/model', () {
      final withNickname = Bike.fromJson({'id': 1, 'brand': 'Ducati', 'model': 'Monster', 'nickname': 'Red Beast'});
      expect(withNickname.displayName, 'Red Beast');

      final withoutNickname = Bike.fromJson({'id': 2, 'brand': 'Yamaha', 'model': 'MT-07'});
      expect(withoutNickname.displayName, 'Yamaha MT-07');
    });

    test('parses the photo URL when present', () {
      final bike = Bike.fromJson({'id': 1, 'brand': 'Ducati', 'model': 'Monster', 'photo_url': 'https://example.com/bike.jpg'});
      expect(bike.photoUrl, 'https://example.com/bike.jpg');
    });

    test('isDefault defaults to false when absent', () {
      final bike = Bike.fromJson({'id': 1, 'brand': 'Ducati', 'model': 'Monster'});
      expect(bike.isDefault, isFalse);
    });

    test('parses isDefault when true', () {
      final bike = Bike.fromJson({'id': 1, 'brand': 'Ducati', 'model': 'Monster', 'is_default': true});
      expect(bike.isDefault, isTrue);
    });

    test('photos default to an empty list when absent', () {
      final bike = Bike.fromJson({'id': 1, 'brand': 'Ducati', 'model': 'Monster'});
      expect(bike.photos, isEmpty);
    });

    test('parses the photo gallery when present', () {
      final bike = Bike.fromJson({
        'id': 1,
        'brand': 'Ducati',
        'model': 'Monster',
        'photos': [
          {'id': 10, 'url': 'https://example.com/a.jpg'},
          {'id': 11, 'url': 'https://example.com/b.jpg'},
        ],
      });
      expect(bike.photos, hasLength(2));
      expect(bike.photos.first.id, 10);
      expect(bike.photos.last.url, 'https://example.com/b.jpg');
    });
  });

  group('AppUser', () {
    test('parses username and avatarUrl when present', () {
      final user = AppUser.fromJson({
        'id': 1,
        'name': 'Marco',
        'username': 'marco_rides',
        'email': 'marco@example.com',
        'avatar_url': 'https://example.com/avatar.jpg',
      });
      expect(user.username, 'marco_rides');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
    });

    test('username and avatarUrl default to null when absent', () {
      final user = AppUser.fromJson({'id': 1, 'name': 'Marco', 'email': 'marco@example.com'});
      expect(user.username, isNull);
      expect(user.avatarUrl, isNull);
    });
  });

  group('UserSummary', () {
    test('parses id, name, username, and avatarUrl', () {
      final summary = UserSummary.fromJson({
        'id': 2,
        'name': 'Sara',
        'username': 'sara_moto',
        'avatar_url': 'https://example.com/sara.jpg',
      });
      expect(summary.id, 2);
      expect(summary.username, 'sara_moto');
      expect(summary.avatarUrl, 'https://example.com/sara.jpg');
    });
  });

  group('RiderProfile', () {
    test('computes distanceKm from distanceMeters', () {
      final profile = RiderProfile.fromJson({
        'id': 1,
        'name': 'Marco',
        'username': 'marco_rides',
        'avatar_url': null,
        'member_since': '2025-01-01T00:00:00Z',
        'rides_count': 4,
        'distance_meters': 12000,
      });
      expect(profile.distanceKm, 12.0);
      expect(profile.memberSince.year, 2025);
      expect(profile.isFollowing, isFalse);
    });

    test('parses follow state and counts when present', () {
      final profile = RiderProfile.fromJson({
        'id': 1,
        'name': 'Marco',
        'username': 'marco_rides',
        'member_since': '2025-01-01T00:00:00Z',
        'rides_count': 4,
        'distance_meters': 12000,
        'followers_count': 9,
        'following_count': 3,
        'is_following': true,
      });
      expect(profile.followersCount, 9);
      expect(profile.followingCount, 3);
      expect(profile.isFollowing, isTrue);
    });

    test('copyWith updates follow state without losing other fields', () {
      final profile = RiderProfile.fromJson({
        'id': 1,
        'name': 'Marco',
        'username': 'marco_rides',
        'member_since': '2025-01-01T00:00:00Z',
        'rides_count': 4,
        'distance_meters': 12000,
        'followers_count': 9,
        'is_following': false,
      });
      final followed = profile.copyWith(isFollowing: true, followersCount: 10);
      expect(followed.isFollowing, isTrue);
      expect(followed.followersCount, 10);
      expect(followed.name, 'Marco');
    });
  });

  group('Ride', () {
    Map<String, dynamic> sampleJson({List<dynamic>? track, List<dynamic>? polyline}) => {
          'id': 1,
          'title': 'Sunday Loop',
          'description': null,
          'started_at': '2026-01-01T10:00:00Z',
          'duration_seconds': 3600,
          'distance_meters': 45000,
          'avg_speed_kmh': '55.50',
          'max_speed_kmh': '120.00',
          'user': {'id': 1, 'name': 'Marco'},
          'bike': null,
          'polyline': polyline ?? [],
          if (track != null) 'track': track,
          'photos': [],
          'likes_count': 3,
          'comments_count': 1,
          'liked_by_me': true,
        };

    test('parses decimal fields sent as strings', () {
      final ride = Ride.fromJson(sampleJson());
      expect(ride.avgSpeedKmh, 55.5);
      expect(ride.maxSpeedKmh, 120.0);
      expect(ride.distanceKm, 45.0);
    });

    test('parses the author as a UserSummary with username/avatar', () {
      final json = sampleJson();
      json['user'] = {'id': 1, 'name': 'Marco', 'username': 'marco_rides', 'avatar_url': 'https://example.com/a.jpg'};
      final ride = Ride.fromJson(json);

      expect(ride.user.username, 'marco_rides');
      expect(ride.user.avatarUrl, 'https://example.com/a.jpg');
    });

    test('participants default to an empty list when absent', () {
      final ride = Ride.fromJson(sampleJson());
      expect(ride.participants, isEmpty);
    });

    test('parses tagged participants when present', () {
      final json = sampleJson();
      json['participants'] = [
        {'id': 2, 'name': 'Sara', 'username': 'sara_moto', 'avatar_url': null},
      ];
      final ride = Ride.fromJson(json);

      expect(ride.participants, hasLength(1));
      expect(ride.participants.first.name, 'Sara');
      expect(ride.participants.first.username, 'sara_moto');
    });

    test('routeLine falls back to polyline when track is absent (feed responses)', () {
      final ride = Ride.fromJson(sampleJson(polyline: [
        {'lat': 1.0, 'lng': 2.0},
      ]));
      expect(ride.track, isNull);
      expect(ride.routeLine.length, 1);
    });

    test('routeLine prefers the full track when present (detail responses)', () {
      final ride = Ride.fromJson(sampleJson(
        polyline: [
          {'lat': 1.0, 'lng': 2.0},
        ],
        track: [
          {'lat': 1.0, 'lng': 2.0},
          {'lat': 1.1, 'lng': 2.1},
        ],
      ));
      expect(ride.routeLine.length, 2);
    });

    test('copyWith updates like state without losing other fields', () {
      final ride = Ride.fromJson(sampleJson());
      final liked = ride.copyWith(likedByMe: false, likesCount: 2);
      expect(liked.likedByMe, false);
      expect(liked.likesCount, 2);
      expect(liked.title, ride.title);
    });

    test('speedScore and speedingEvents default to null when absent (older rides)', () {
      final ride = Ride.fromJson(sampleJson());
      expect(ride.speedScore, isNull);
      expect(ride.speedingEvents, isNull);
    });

    test('parses speedScore and speedingEvents when present', () {
      final json = sampleJson()
        ..['speed_score'] = 72
        ..['speeding_events'] = [
          {
            'started_at': '2026-01-01T10:05:00Z',
            'duration_seconds': 12,
            'limit_kmh': 50,
            'max_speed_kmh': 78.5,
            'excess_kmh': 28.5,
          },
        ];
      final ride = Ride.fromJson(json);

      expect(ride.speedScore, 72);
      expect(ride.speedingEvents, hasLength(1));
      expect(ride.speedingEvents!.first.limitKmh, 50.0);
      expect(ride.speedingEvents!.first.maxSpeedKmh, 78.5);
      expect(ride.speedingEvents!.first.durationSeconds, 12);
    });
  });

  group('RidePhoto', () {
    test('parses coordinates when present', () {
      final photo = RidePhoto.fromJson({'id': 1, 'url': 'https://example.com/a.jpg', 'lat': 43.5, 'lng': 5.4});
      expect(photo.lat, 43.5);
      expect(photo.lng, 5.4);
    });

    test('coordinates default to null when absent', () {
      final photo = RidePhoto.fromJson({'id': 1, 'url': 'https://example.com/a.jpg'});
      expect(photo.lat, isNull);
      expect(photo.lng, isNull);
    });
  });

  group('MyPhoto', () {
    Map<String, dynamic> sampleJson({double? lat, double? lng}) => {
          'id': 7,
          'url': 'https://example.com/photo.jpg',
          'lat': lat,
          'lng': lng,
          'created_at': '2026-01-02T09:00:00Z',
          'ride': {'id': 3, 'title': 'Coastal Loop', 'started_at': '2026-01-02T08:00:00Z'},
        };

    test('parses ride info alongside the photo', () {
      final photo = MyPhoto.fromJson(sampleJson(lat: 43.5, lng: 5.4));
      expect(photo.rideId, 3);
      expect(photo.rideTitle, 'Coastal Loop');
      expect(photo.hasLocation, isTrue);
    });

    test('hasLocation is false when coordinates are missing', () {
      final photo = MyPhoto.fromJson(sampleJson());
      expect(photo.lat, isNull);
      expect(photo.hasLocation, isFalse);
    });
  });

  group('RiderStats', () {
    test('computes km from meters', () {
      final stats = RiderStats.fromJson({
        'rides_count': 5,
        'distance_meters': 12500,
        'week_rides_count': 2,
        'week_distance_meters': 4000,
      });
      expect(stats.distanceKm, 12.5);
      expect(stats.weekDistanceKm, 4.0);
    });
  });
}
