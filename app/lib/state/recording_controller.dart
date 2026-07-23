import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../core/format.dart';
import '../core/models/captured_photo.dart';
import '../core/models/track_point.dart';
import 'recording_task_handler.dart';

enum RecordingState { idle, recording, paused, stopped }

const _pauseResumeButtonId = 'pause_resume';

/// Live GPS ride recording: filters noisy fixes, accumulates distance via
/// the haversine formula, and tracks elapsed time - independent of any
/// widget lifecycle so a screen rebuild never loses in-progress data.
///
/// The foreground service + notification (with a Pause/Resume button and
/// live stats) is owned by flutter_foreground_task, which is what actually
/// keeps the app process alive with the screen locked - geolocator's
/// position stream just keeps running in this same (kept-alive) process.
class RecordingController extends ChangeNotifier {
  RecordingController() {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  RecordingState state = RecordingState.idle;
  final List<TrackPoint> track = [];
  final List<CapturedPhoto> photos = [];

  double distanceMeters = 0;
  double currentSpeedKmh = 0;
  double maxSpeedKmh = 0;
  Duration elapsed = Duration.zero;
  DateTime? startedAt;

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  Position? _lastKept;
  Position? _lastPosition;
  DateTime? _lastResumeTime;
  bool _serviceInitialized = false;

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

    if (defaultTargetPlatform == TargetPlatform.android) {
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    }

    return await Geolocator.isLocationServiceEnabled();
  }

  void _initForegroundTaskIfNeeded() {
    if (_serviceInitialized) return;
    _serviceInitialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'redl_ride_recording',
        channelName: 'Ride recording',
        channelDescription: 'Shows live stats while a ride is being recorded.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  void _onTaskData(Object data) {
    if (data is Map && data['buttonPressed'] == _pauseResumeButtonId) {
      state == RecordingState.paused ? resume() : pause();
    }
  }

  Future<bool> start() async {
    if (!await _ensurePermission()) return false;

    _initForegroundTaskIfNeeded();
    await FlutterForegroundTask.startService(
      serviceId: 501,
      notificationTitle: 'Recording your ride',
      notificationText: '0.00 km · 0s',
      notificationButtons: const [NotificationButton(id: _pauseResumeButtonId, text: 'Pause')],
      callback: recordingTaskHandlerCallback,
    );

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
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

  void _onPosition(Position position) {
    if (position.accuracy > _minAccuracyMeters) return;

    _lastPosition = position;

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
      _updateNotification();
      notifyListeners();
    });
  }

  void _updateNotification() {
    if (state != RecordingState.recording && state != RecordingState.paused) return;
    FlutterForegroundTask.updateService(
      notificationTitle: state == RecordingState.paused ? 'Ride paused' : 'Recording your ride',
      notificationText: '${formatDistanceKm(distanceMeters / 1000)} · ${formatDuration(elapsed)}',
      notificationButtons: [
        NotificationButton(id: _pauseResumeButtonId, text: state == RecordingState.paused ? 'Resume' : 'Pause'),
      ],
    );
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
    _updateNotification();
    notifyListeners();
  }

  void resume() {
    if (state != RecordingState.paused) return;
    _lastResumeTime = DateTime.now();
    _positionSub?.resume();
    _startTicker();
    state = RecordingState.recording;
    _updateNotification();
    notifyListeners();
  }

  void stop() {
    _positionSub?.cancel();
    _ticker?.cancel();
    if (_lastResumeTime != null && state == RecordingState.recording) {
      elapsed += DateTime.now().difference(_lastResumeTime!);
    }
    state = RecordingState.stopped;
    FlutterForegroundTask.stopService();
    notifyListeners();
  }

  double get avgSpeedKmh {
    final hours = elapsed.inMilliseconds / 3600000;
    if (hours <= 0) return 0;
    return (distanceMeters / 1000) / hours;
  }

  double? get lastLat => _lastPosition?.latitude;
  double? get lastLng => _lastPosition?.longitude;

  void addPhoto(CapturedPhoto photo) {
    photos.add(photo);
    notifyListeners();
  }

  void reset() {
    _positionSub?.cancel();
    _ticker?.cancel();
    track.clear();
    photos.clear();
    distanceMeters = 0;
    currentSpeedKmh = 0;
    maxSpeedKmh = 0;
    elapsed = Duration.zero;
    startedAt = null;
    _lastKept = null;
    _lastPosition = null;
    _lastResumeTime = null;
    state = RecordingState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _positionSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }
}
