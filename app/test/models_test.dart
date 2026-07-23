import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/models/bike.dart';
import 'package:redl/core/models/ride.dart';
import 'package:redl/core/models/rider_stats.dart';
import 'package:redl/core/models/track_point.dart';

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
