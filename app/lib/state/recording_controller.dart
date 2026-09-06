import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/format.dart';
import '../core/models/captured_photo.dart';
import '../core/models/point_of_interest.dart';
import '../core/models/ride_sensor_stats.dart';
import '../core/models/track_point.dart';
import '../core/repositories/ride_repository.dart';
import '../core/ride_draft_store.dart';
import '../core/sensor_stats_tracker.dart';
import 'recording_task_handler.dart';

/// A point of interest the rider tried to add while offline (or the
/// request otherwise failed) - retried on the next GPS fix rather than
/// lost, per the project doc's offline queue for live POIs.
class _PendingPoiSubmission {
  _PendingPoiSubmission({
    required this.lat,
    required this.lng,
    this.title,
    this.photo,
  });

  final double lat;
  final double lng;
  final String? title;
  final File? photo;
}

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
  RecordingController(this._rideRepository) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  final RideRepository _rideRepository;
  final RideDraftStore _draftStore = RideDraftStore();

  RecordingState state = RecordingState.idle;
  final List<TrackPoint> track = [];
  final List<CapturedPhoto> photos = [];
  final List<PointOfInterest> poisAdded = [];
  final List<_PendingPoiSubmission> _pendingPois = [];
  bool _flushingPois = false;

  /// The backend ride id, obtained from POST /rides/start - either right
  /// away, or once connectivity comes back if the ride started offline (see
  /// [pendingStart]). Recording itself never waits on it.
  int? rideId;

  /// True while `POST /rides/start` hasn't succeeded yet - recording
  /// proceeds locally regardless, and this is retried in the background
  /// until it lands (backlog BUG-2).
  bool _pendingStart = false;
  bool get pendingStart => _pendingStart;
  Timer? _startRetryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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

  StreamSubscription<AccelerometerEvent>? _accelSub;
  SensorStatsTracker? _sensorTracker;

  int get pendingPoiCount => _pendingPois.length;

  /// Whether sensor capture is running for this ride - shown as a small
  /// discreet indicator on the recording screen (project doc 9.4).
  bool get sensorsActive => _accelSub != null;

  RideSensorStats? get sensorStats => _sensorTracker?.snapshot();

  static const _minAccuracyMeters = 25.0;
  static const _minDistanceFilterMeters = 5.0;

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
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
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
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

  /// Starts recording immediately - GPS/sensor capture and the foreground
  /// service don't wait on the network. `POST /rides/start` is attempted in
  /// the background and retried until it lands (see [_attemptRemoteStart]),
  /// so a ride started offline is never lost (backlog BUG-2).
  Future<bool> start({bool sensorsEnabled = false}) async {
    if (!await _ensurePermission()) return false;

    _initForegroundTaskIfNeeded();
    await FlutterForegroundTask.startService(
      serviceId: 501,
      notificationTitle: 'Recording your ride',
      notificationText: '0.00 km · 0s',
      notificationButtons: const [
        NotificationButton(id: _pauseResumeButtonId, text: 'Pause'),
      ],
      callback: recordingTaskHandlerCallback,
    );

    state = RecordingState.recording;
    startedAt = DateTime.now();
    _lastResumeTime = DateTime.now();
    _subscribe();
    _startTicker();
    if (sensorsEnabled) _subscribeToSensors();
    _persist();
    notifyListeners();

    unawaited(_attemptRemoteStart());
    return true;
  }

  Future<void> _attemptRemoteStart() async {
    if (rideId != null || state == RecordingState.idle) return;
    try {
      rideId = await _rideRepository.start();
      _pendingStart = false;
      _cancelStartRetry();
      unawaited(_flushPendingPois());
    } catch (_) {
      _pendingStart = true;
      _scheduleStartRetry();
    }
    _persist();
    notifyListeners();
  }

  void _scheduleStartRetry() {
    _startRetryTimer?.cancel();
    _startRetryTimer = Timer(const Duration(seconds: 15), _attemptRemoteStart);
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (_pendingStart && !results.contains(ConnectivityResult.none)) {
        _attemptRemoteStart();
      }
    });
  }

  void _cancelStartRetry() {
    _startRetryTimer?.cancel();
    _startRetryTimer = null;
    unawaited(_connectivitySub?.cancel());
    _connectivitySub = null;
  }

  /// Writes the current recording to disk so it survives an app kill or
  /// crash, not just an in-memory session (backlog BUG-2). Best-effort - a
  /// local disk write failure shouldn't interrupt recording.
  void _persist() {
    if (state == RecordingState.idle || state == RecordingState.stopped) {
      return;
    }
    unawaited(
      _draftStore
          .saveRecording(
            RideRecordingDraft(
              rideId: rideId,
              recording: state == RecordingState.recording,
              startedAt: startedAt ?? DateTime.now(),
              elapsedSeconds: elapsed.inSeconds,
              distanceMeters: distanceMeters,
              maxSpeedKmh: maxSpeedKmh,
              track: List.of(track),
              sensorsEnabled: sensorsActive,
              photos: photos
                  .map((p) => PersistedPhoto(path: p.file.path, lat: p.lat, lng: p.lng))
                  .toList(),
              pendingPois: _pendingPois
                  .map(
                    (p) => PersistedPendingPoi(
                      lat: p.lat,
                      lng: p.lng,
                      title: p.title,
                      photoPath: p.photo?.path,
                    ),
                  )
                  .toList(),
            ),
          )
          .catchError((_) {}),
    );
  }

  /// Whether a recording survived an app restart and can be resumed.
  Future<RideRecordingDraft?> checkForRecoverableRecording() => _draftStore.loadRecording();

  /// Rehydrates and resumes a recording that survived an app restart -
  /// continues GPS/sensor capture and the foreground service right where it
  /// left off, instead of losing it (backlog BUG-2).
  Future<void> resumeFromDraft(RideRecordingDraft draft) async {
    if (!await _ensurePermission()) return;

    rideId = draft.rideId;
    _pendingStart = draft.rideId == null;
    startedAt = draft.startedAt;
    distanceMeters = draft.distanceMeters;
    maxSpeedKmh = draft.maxSpeedKmh;
    elapsed = Duration(seconds: draft.elapsedSeconds);
    track
      ..clear()
      ..addAll(draft.track);
    photos
      ..clear()
      ..addAll(
        draft.photos
            .where((p) => File(p.path).existsSync())
            .map((p) => CapturedPhoto(file: XFile(p.path), lat: p.lat, lng: p.lng)),
      );
    _pendingPois
      ..clear()
      ..addAll(
        draft.pendingPois.map(
          (p) => _PendingPoiSubmission(
            lat: p.lat,
            lng: p.lng,
            title: p.title,
            photo: p.photoPath != null && File(p.photoPath!).existsSync() ? File(p.photoPath!) : null,
          ),
        ),
      );

    if (track.isNotEmpty) {
      final last = track.last;
      final synthetic = Position(
        latitude: last.lat,
        longitude: last.lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: last.alt ?? 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: (last.speed ?? 0) / 3.6,
        speedAccuracy: 0,
      );
      _lastKept = synthetic;
      _lastPosition = synthetic;
    }

    _initForegroundTaskIfNeeded();
    await FlutterForegroundTask.startService(
      serviceId: 501,
      notificationTitle: draft.recording ? 'Recording your ride' : 'Ride paused',
      notificationText: '${formatDistanceKm(distanceMeters / 1000)} · ${formatDuration(elapsed)}',
      notificationButtons: [
        NotificationButton(id: _pauseResumeButtonId, text: draft.recording ? 'Pause' : 'Resume'),
      ],
      callback: recordingTaskHandlerCallback,
    );

    state = draft.recording ? RecordingState.recording : RecordingState.paused;
    _subscribe();
    if (draft.recording) {
      _lastResumeTime = DateTime.now();
      _startTicker();
    }
    if (draft.sensorsEnabled) _subscribeToSensors();
    if (_pendingStart) unawaited(_attemptRemoteStart());
    _persist();
    notifyListeners();
  }

  void _subscribeToSensors() {
    _sensorTracker = SensorStatsTracker();
    _accelSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(_sensorTracker!.onData);
  }

  void _subscribe() {
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 2),
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    if (position.accuracy > _minAccuracyMeters) return;

    _lastPosition = position;

    if (_lastKept != null) {
      final segment = Geolocator.distanceBetween(
        _lastKept!.latitude,
        _lastKept!.longitude,
        position.latitude,
        position.longitude,
      );
      if (segment < _minDistanceFilterMeters) return;
      distanceMeters += segment;
    }

    _lastKept = position;

    final speedKmh = math.max(0, position.speed) * 3.6;
    currentSpeedKmh = speedKmh;
    maxSpeedKmh = math.max(maxSpeedKmh, speedKmh);

    track.add(
      TrackPoint(
        lat: position.latitude,
        lng: position.longitude,
        alt: position.altitude,
        speed: speedKmh,
        t: DateTime.now().toIso8601String(),
      ),
    );

    notifyListeners();
    _persist();
    unawaited(_flushPendingPois());
  }

  /// Adds a point of interest at the rider's current position, without
  /// pausing GPS tracking. Sent immediately if the ride id is known;
  /// otherwise (or if the request fails - offline, timeout, ...) queued
  /// locally and retried on the next GPS fix or once the ride id lands.
  Future<void> addPoi({String? title, File? photo}) async {
    final position = _lastPosition;
    if (position == null) return;
    final id = rideId;

    if (id == null) {
      _pendingPois.add(
        _PendingPoiSubmission(lat: position.latitude, lng: position.longitude, title: title, photo: photo),
      );
      notifyListeners();
      _persist();
      return;
    }

    try {
      final poi = await _rideRepository.addPoi(
        id,
        lat: position.latitude,
        lng: position.longitude,
        title: title,
        photo: photo,
      );
      poisAdded.add(poi);
    } catch (_) {
      _pendingPois.add(
        _PendingPoiSubmission(
          lat: position.latitude,
          lng: position.longitude,
          title: title,
          photo: photo,
        ),
      );
    }
    notifyListeners();
    _persist();
  }

  Future<void> _flushPendingPois() async {
    final id = rideId;
    if (id == null || _flushingPois || _pendingPois.isEmpty) return;
    _flushingPois = true;

    final stillPending = <_PendingPoiSubmission>[];
    for (final submission in List.of(_pendingPois)) {
      try {
        final poi = await _rideRepository.addPoi(
          id,
          lat: submission.lat,
          lng: submission.lng,
          title: submission.title,
          photo: submission.photo,
        );
        poisAdded.add(poi);
      } catch (_) {
        stillPending.add(submission);
      }
    }

    _pendingPois
      ..clear()
      ..addAll(stillPending);
    _flushingPois = false;
    notifyListeners();
    _persist();
  }

  /// Abandons the ride started with [start] without publishing it.
  Future<void> discard() async {
    _cancelStartRetry();
    final id = rideId;
    if (id != null) {
      try {
        await _rideRepository.discard(id);
      } catch (_) {
        // Best-effort - an orphaned in_progress ride is harmless (never shown to anyone but its owner).
      }
    }
    await _draftStore.clearRecording();
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
    if (state != RecordingState.recording && state != RecordingState.paused) {
      return;
    }
    FlutterForegroundTask.updateService(
      notificationTitle: state == RecordingState.paused
          ? 'Ride paused'
          : 'Recording your ride',
      notificationText:
          '${formatDistanceKm(distanceMeters / 1000)} · ${formatDuration(elapsed)}',
      notificationButtons: [
        NotificationButton(
          id: _pauseResumeButtonId,
          text: state == RecordingState.paused ? 'Resume' : 'Pause',
        ),
      ],
    );
  }

  void pause() {
    if (state != RecordingState.recording) return;
    _positionSub?.pause();
    _accelSub?.pause();
    _ticker?.cancel();
    if (_lastResumeTime != null) {
      elapsed += DateTime.now().difference(_lastResumeTime!);
      _lastResumeTime = null;
    }
    currentSpeedKmh = 0;
    state = RecordingState.paused;
    _updateNotification();
    notifyListeners();
    _persist();
  }

  void resume() {
    if (state != RecordingState.paused) return;
    _lastResumeTime = DateTime.now();
    _positionSub?.resume();
    _accelSub?.resume();
    _startTicker();
    state = RecordingState.recording;
    _updateNotification();
    notifyListeners();
    _persist();
  }

  void stop() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _accelSub = null;
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
    _persist();
  }

  void reset() {
    _positionSub?.cancel();
    _accelSub?.cancel();
    _accelSub = null;
    _sensorTracker = null;
    _ticker?.cancel();
    _cancelStartRetry();
    track.clear();
    photos.clear();
    poisAdded.clear();
    _pendingPois.clear();
    rideId = null;
    _pendingStart = false;
    distanceMeters = 0;
    currentSpeedKmh = 0;
    maxSpeedKmh = 0;
    elapsed = Duration.zero;
    startedAt = null;
    _lastKept = null;
    _lastPosition = null;
    _lastResumeTime = null;
    state = RecordingState.idle;
    unawaited(_draftStore.clearRecording());
    notifyListeners();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _positionSub?.cancel();
    _accelSub?.cancel();
    _ticker?.cancel();
    _cancelStartRetry();
    super.dispose();
  }
}
