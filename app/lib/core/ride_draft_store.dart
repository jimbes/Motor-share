import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models/ride_sensor_stats.dart';
import 'models/track_point.dart';

/// A photo captured or picked for a ride, referenced by its local path so
/// it survives a JSON round-trip to disk.
class PersistedPhoto {
  const PersistedPhoto({required this.path, this.lat, this.lng});

  final String path;
  final double? lat;
  final double? lng;

  Map<String, dynamic> toJson() => {
    'path': path,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
  };

  factory PersistedPhoto.fromJson(Map<String, dynamic> json) => PersistedPhoto(
    path: json['path'] as String,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );
}

/// A point of interest that failed to submit and is queued for retry -
/// persisted so the queue survives an app restart, not just an in-memory
/// session (mirrors the in-memory queue in RecordingController).
class PersistedPendingPoi {
  const PersistedPendingPoi({
    required this.lat,
    required this.lng,
    this.title,
    this.photoPath,
  });

  final double lat;
  final double lng;
  final String? title;
  final String? photoPath;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    if (title != null) 'title': title,
    if (photoPath != null) 'photo_path': photoPath,
  };

  factory PersistedPendingPoi.fromJson(Map<String, dynamic> json) =>
      PersistedPendingPoi(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        title: json['title'] as String?,
        photoPath: json['photo_path'] as String?,
      );
}

/// A snapshot of an in-progress recording, written to disk continuously so
/// the ride survives an app kill or crash - not just a network blip
/// (backlog BUG-2). [rideId] is null while `POST /rides/start` hasn't
/// succeeded yet.
class RideRecordingDraft {
  RideRecordingDraft({
    required this.rideId,
    this.bikeId,
    required this.recording,
    required this.startedAt,
    required this.elapsedSeconds,
    required this.distanceMeters,
    required this.maxSpeedKmh,
    required this.track,
    required this.sensorsEnabled,
    required this.photos,
    required this.pendingPois,
  });

  final int? rideId;

  /// The bike picked before recording started, if any (backlog FEAT-3).
  final int? bikeId;

  /// True if recording, false if paused.
  final bool recording;
  final DateTime startedAt;
  final int elapsedSeconds;
  final double distanceMeters;
  final double maxSpeedKmh;
  final List<TrackPoint> track;
  final bool sensorsEnabled;
  final List<PersistedPhoto> photos;
  final List<PersistedPendingPoi> pendingPois;

  Map<String, dynamic> toJson() => {
    if (rideId != null) 'ride_id': rideId,
    if (bikeId != null) 'bike_id': bikeId,
    'recording': recording,
    'started_at': startedAt.toIso8601String(),
    'elapsed_seconds': elapsedSeconds,
    'distance_meters': distanceMeters,
    'max_speed_kmh': maxSpeedKmh,
    'track': track.map((p) => p.toJson()).toList(),
    'sensors_enabled': sensorsEnabled,
    'photos': photos.map((p) => p.toJson()).toList(),
    'pending_pois': pendingPois.map((p) => p.toJson()).toList(),
  };

  factory RideRecordingDraft.fromJson(Map<String, dynamic> json) =>
      RideRecordingDraft(
        rideId: json['ride_id'] as int?,
        bikeId: json['bike_id'] as int?,
        recording: json['recording'] as bool? ?? true,
        startedAt: DateTime.parse(json['started_at'] as String),
        elapsedSeconds: json['elapsed_seconds'] as int? ?? 0,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
        maxSpeedKmh: (json['max_speed_kmh'] as num?)?.toDouble() ?? 0,
        track: (json['track'] as List<dynamic>? ?? const [])
            .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        sensorsEnabled: json['sensors_enabled'] as bool? ?? false,
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .map((e) => PersistedPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingPois: (json['pending_pois'] as List<dynamic>? ?? const [])
            .map((e) => PersistedPendingPoi.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A fully-recorded ride awaiting a successful `PATCH /rides/{id}/finish` -
/// persisted the moment the rider reaches the save screen so a failed (or
/// interrupted) finish never loses the ride (backlog BUG-2).
class RidePendingFinish {
  RidePendingFinish({
    required this.rideId,
    required this.title,
    this.description,
    this.bikeId,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.track,
    this.sensorStats,
    required this.photos,
    required this.companionUsernames,
    this.hidden = false,
  });

  final int rideId;
  final String title;
  final String? description;
  final int? bikeId;
  final int durationSeconds;
  final int distanceMeters;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final List<TrackPoint> track;
  final RideSensorStats? sensorStats;
  final List<PersistedPhoto> photos;
  final List<String> companionUsernames;
  final bool hidden;

  Map<String, dynamic> toJson() => {
    'ride_id': rideId,
    'title': title,
    if (description != null) 'description': description,
    if (bikeId != null) 'bike_id': bikeId,
    'duration_seconds': durationSeconds,
    'distance_meters': distanceMeters,
    'avg_speed_kmh': avgSpeedKmh,
    'max_speed_kmh': maxSpeedKmh,
    'track': track.map((p) => p.toJson()).toList(),
    if (sensorStats != null) 'sensor_stats': sensorStats!.toJson(),
    'photos': photos.map((p) => p.toJson()).toList(),
    'companion_usernames': companionUsernames,
    'hidden': hidden,
  };

  factory RidePendingFinish.fromJson(Map<String, dynamic> json) =>
      RidePendingFinish(
        rideId: json['ride_id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        bikeId: json['bike_id'] as int?,
        durationSeconds: json['duration_seconds'] as int,
        distanceMeters: json['distance_meters'] as int,
        avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
        maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
        track: (json['track'] as List<dynamic>? ?? const [])
            .map((e) => TrackPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        sensorStats: json['sensor_stats'] != null
            ? RideSensorStats.fromJson(
                json['sensor_stats'] as Map<String, dynamic>,
              )
            : null,
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .map((e) => PersistedPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        companionUsernames:
            (json['companion_usernames'] as List<dynamic>? ?? const [])
                .map((e) => e as String)
                .toList(),
        hidden: json['hidden'] as bool? ?? false,
      );
}

/// Persists the active recording and/or a not-yet-confirmed finish to disk
/// so a lost connection - or the app being killed - during a ride never
/// loses it (backlog BUG-2). Writes are atomic (temp file + rename) so a
/// crash mid-write can't corrupt the file.
class RideDraftStore {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/ride_drafts');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeAtomic(File file, String contents) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(file.path);
  }

  Future<void> saveRecording(RideRecordingDraft draft) async {
    final dir = await _dir();
    await _writeAtomic(
      File('${dir.path}/active_ride.json'),
      jsonEncode(draft.toJson()),
    );
  }

  Future<RideRecordingDraft?> loadRecording() async {
    final file = File('${(await _dir()).path}/active_ride.json');
    if (!await file.exists()) return null;
    try {
      return RideRecordingDraft.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRecording() async {
    final file = File('${(await _dir()).path}/active_ride.json');
    if (await file.exists()) await file.delete();
  }

  Future<void> savePendingFinish(RidePendingFinish draft) async {
    final dir = await _dir();
    await _writeAtomic(
      File('${dir.path}/pending_finish.json'),
      jsonEncode(draft.toJson()),
    );
  }

  Future<RidePendingFinish?> loadPendingFinish() async {
    final file = File('${(await _dir()).path}/pending_finish.json');
    if (!await file.exists()) return null;
    try {
      return RidePendingFinish.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingFinish() async {
    final file = File('${(await _dir()).path}/pending_finish.json');
    if (await file.exists()) await file.delete();
  }
}
