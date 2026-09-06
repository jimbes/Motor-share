import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/models/ride_sensor_stats.dart';
import 'package:redl/core/models/track_point.dart';
import 'package:redl/core/ride_draft_store.dart';

void main() {
  group('RideRecordingDraft', () {
    test('round-trips through JSON, including a null ride id', () {
      final draft = RideRecordingDraft(
        rideId: null,
        recording: true,
        startedAt: DateTime.utc(2026, 9, 6, 10, 30),
        elapsedSeconds: 125,
        distanceMeters: 4200.5,
        maxSpeedKmh: 87.2,
        track: const [TrackPoint(lat: 45.75, lng: 4.85, speed: 42)],
        sensorsEnabled: true,
        photos: const [
          PersistedPhoto(path: '/tmp/a.jpg', lat: 45.75, lng: 4.85),
        ],
        pendingPois: const [
          PersistedPendingPoi(lat: 45.76, lng: 4.86, title: 'Viewpoint'),
        ],
      );

      final restored = RideRecordingDraft.fromJson(draft.toJson());

      expect(restored.rideId, isNull);
      expect(restored.recording, isTrue);
      expect(restored.startedAt, draft.startedAt);
      expect(restored.elapsedSeconds, 125);
      expect(restored.distanceMeters, 4200.5);
      expect(restored.maxSpeedKmh, 87.2);
      expect(restored.track, hasLength(1));
      expect(restored.track.first.lat, 45.75);
      expect(restored.sensorsEnabled, isTrue);
      expect(restored.photos.single.path, '/tmp/a.jpg');
      expect(restored.pendingPois.single.title, 'Viewpoint');
    });

    test('round-trips a known ride id, bike id, and paused state', () {
      final draft = RideRecordingDraft(
        rideId: 42,
        bikeId: 7,
        recording: false,
        startedAt: DateTime.utc(2026, 9, 6, 10, 30),
        elapsedSeconds: 60,
        distanceMeters: 1000,
        maxSpeedKmh: 50,
        track: const [],
        sensorsEnabled: false,
        photos: const [],
        pendingPois: const [],
      );

      final restored = RideRecordingDraft.fromJson(draft.toJson());

      expect(restored.rideId, 42);
      expect(restored.bikeId, 7);
      expect(restored.recording, isFalse);
    });
  });

  group('RidePendingFinish', () {
    test('round-trips through JSON, including sensor stats and companions', () {
      final draft = RidePendingFinish(
        rideId: 7,
        title: 'Morning Ride',
        description: 'Nice loop',
        bikeId: 3,
        durationSeconds: 3600,
        distanceMeters: 42000,
        avgSpeedKmh: 60,
        maxSpeedKmh: 120,
        track: const [TrackPoint(lat: 45.75, lng: 4.85)],
        sensorStats: const RideSensorStats(
          maxLeanAngleLeftDeg: 12,
          maxLeanAngleRightDeg: 38,
          sampleCount: 500,
        ),
        photos: const [PersistedPhoto(path: '/tmp/b.jpg')],
        companionUsernames: const ['alex', 'sam'],
      );

      final restored = RidePendingFinish.fromJson(draft.toJson());

      expect(restored.rideId, 7);
      expect(restored.title, 'Morning Ride');
      expect(restored.description, 'Nice loop');
      expect(restored.bikeId, 3);
      expect(restored.durationSeconds, 3600);
      expect(restored.distanceMeters, 42000);
      expect(restored.sensorStats?.maxLeanAngleLeftDeg, 12);
      expect(restored.sensorStats?.maxLeanAngleRightDeg, 38);
      expect(restored.photos.single.path, '/tmp/b.jpg');
      expect(restored.companionUsernames, ['alex', 'sam']);
    });

    test('description and bike id default to null when absent', () {
      final draft = RidePendingFinish(
        rideId: 7,
        title: 'Morning Ride',
        durationSeconds: 60,
        distanceMeters: 1000,
        avgSpeedKmh: 30,
        maxSpeedKmh: 40,
        track: const [],
        photos: const [],
        companionUsernames: const [],
      );

      final restored = RidePendingFinish.fromJson(draft.toJson());

      expect(restored.description, isNull);
      expect(restored.bikeId, isNull);
      expect(restored.sensorStats, isNull);
    });
  });
}
