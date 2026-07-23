import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../core/models/track_point.dart';

enum RecordingState { idle, recording, paused, stopped }

/// Live GPS ride recording: filters noisy fixes, accumulates distance via
/// the haversine formula, and tracks elapsed time - independent of any
/// widget lifecycle so a screen rebuild never loses in-progress data.
class RecordingController extends ChangeNotifier {
  RecordingController();

  RecordingState state = RecordingState.idle;
  final List<TrackPoint> track = [];

  double distanceMeters = 0;
  double currentSpeedKmh = 0;
  double maxSpeedKmh = 0;
  Duration elapsed = Duration.zero;
  DateTime? startedAt;

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  Position? _lastKept;
  DateTime? _lastResumeTime;

  static const _minAccuracyMeters = 25.0;
  static const _minDistanceFilterMeters = 5.0;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      return false;
    }

    // Android 13+ requires this to be granted for the foreground-service
    // notification (the thing that keeps GPS recording alive with the
    // screen locked) to actually display and persist. Best-effort: a
    // denial here doesn't block recording, it just makes the OS more
    // likely to eventually kill the background service.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await ph.Permission.notification.request();
    }

    return await Geolocator.isLocationServiceEnabled();
  }

  Future<bool> start() async {
    if (!await _ensurePermission()) return false;

    state = RecordingState.recording;
    startedAt = DateTime.now();
    _lastResumeTime = DateTime.now();
    _subscribe();
    _startTicker();
    notifyListeners();
    return true;
  }

  void _subscribe() {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'REDL is recording your ride',
        notificationText: 'Tracking GPS in the background',
        enableWakeLock: true,
      ),
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void _onPosition(Position position) {
    if (position.accuracy > _minAccuracyMeters) return;

    if (_lastKept != null) {
      final segment = Geolocator.distanceBetween(
        _lastKept!.latitude, _lastKept!.longitude,
        position.latitude, position.longitude,
      );
      if (segment < _minDistanceFilterMeters) return;
      distanceMeters += segment;
    }

    _lastKept = position;

    final speedKmh = math.max(0, position.speed) * 3.6;
    currentSpeedKmh = speedKmh;
    maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);

    track.add(TrackPoint(
      lat: position.latitude,
      lng: position.longitude,
      alt: position.altitude,
      speed: speedKmh,
      t: DateTime.now().toIso8601String(),
    ));

    notifyListeners();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastResumeTime != null) {
        elapsed += DateTime.now().difference(_lastResumeTime!);
        _lastResumeTime = DateTime.now();
      }
      notifyListeners();
    });
  }

  void pause() {
    if (state != RecordingState.recording) return;
    _positionSub?.pause();
    _ticker?.cancel();
    if (_lastResumeTime != null) {
      elapsed += DateTime.now().difference(_lastResumeTime!);
      _lastResumeTime = null;
    }
    currentSpeedKmh = 0;
    state = RecordingState.paused;
    notifyListeners();
  }

  void resume() {
    if (state != RecordingState.paused) return;
    _lastResumeTime = DateTime.now();
    _positionSub?.resume();
    _startTicker();
    state = RecordingState.recording;
    notifyListeners();
  }

  void stop() {
    _positionSub?.cancel();
    _ticker?.cancel();
    if (_lastResumeTime != null && state == RecordingState.recording) {
      elapsed += DateTime.now().difference(_lastResumeTime!);
    }
    state = RecordingState.stopped;
    notifyListeners();
  }

  double get avgSpeedKmh {
    final hours = elapsed.inMilliseconds / 3600000;
    if (hours <= 0) return 0;
    return (distanceMeters / 1000) / hours;
  }

  void reset() {
    _positionSub?.cancel();
    _ticker?.cancel();
    track.clear();
    distanceMeters = 0;
    currentSpeedKmh = 0;
    maxSpeedKmh = 0;
    elapsed = Duration.zero;
    startedAt = null;
    _lastKept = null;
    _lastResumeTime = null;
    state = RecordingState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
