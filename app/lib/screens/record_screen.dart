import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/car_stats_channel.dart';
import '../core/format.dart';
import '../core/models/bike.dart';
import '../core/models/captured_photo.dart';
import '../core/repositories/bike_repository.dart';
import '../core/repositories/ride_repository.dart';
import '../core/ride_draft_store.dart';
import '../core/speed_color.dart';
import '../l10n/app_localizations.dart';
import '../state/recording_controller.dart';
import '../state/sensor_settings_provider.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/battery_optimization_prompt.dart';
import '../widgets/redl_buttons.dart';
import 'ride_summary_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late final RecordingController _controller;
  final _mapController = MapController();
  String? _permissionError;
  List<Bike> _bikes = [];
  Bike? _selectedBike;

  @override
  void initState() {
    super.initState();
    _controller = RecordingController(context.read<RideRepository>());
    _controller.addListener(_onTick);
    unawaited(_recoverPersistedRide());
    unawaited(_loadBikes());
    // Lets the Android Auto car screen drive the same recording session
    // the phone shows (backlog FEAT-4) - Stop only ends GPS tracking, since
    // finishing the save form isn't something to do from behind the wheel.
    CarStatsChannel().setCommandHandler(
      onStart: _start,
      onPause: _controller.pause,
      onResume: _controller.resume,
      onStop: _controller.stop,
    );
  }

  /// Lets the rider pick which bike this ride is on before they even tap
  /// Start, instead of only at the end (backlog FEAT-3) - only shown when
  /// there's an actual choice to make.
  Future<void> _loadBikes() async {
    try {
      final bikes = await context.read<BikeRepository>().list();
      if (!mounted) return;
      setState(() {
        _bikes = bikes;
        final defaultBikes = bikes.where((b) => b.isDefault);
        _selectedBike = defaultBikes.isEmpty ? null : defaultBikes.first;
      });
    } catch (_) {
      // Non-fatal - the rider can still record without picking a bike.
    }
  }

  /// Recovers a ride that survived an app restart - either one still
  /// mid-recording (resumes it in place) or one that finished recording but
  /// never confirmed `PATCH /rides/{id}/finish` (reopens the save screen
  /// with everything prefilled and retries automatically). Neither case
  /// should lose the ride (backlog BUG-2).
  Future<void> _recoverPersistedRide() async {
    final store = RideDraftStore();
    final pendingFinish = await store.loadPendingFinish();
    if (pendingFinish != null) {
      // The recording phase is over for this ride - drop any stale
      // in-progress draft left over for the same attempt.
      await store.clearRecording();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideSummaryScreen.save(
            rideId: pendingFinish.rideId,
            startedAt: DateTime.now().subtract(
              Duration(seconds: pendingFinish.durationSeconds),
            ),
            durationSeconds: pendingFinish.durationSeconds,
            distanceMeters: pendingFinish.distanceMeters,
            avgSpeedKmh: pendingFinish.avgSpeedKmh,
            maxSpeedKmh: pendingFinish.maxSpeedKmh,
            track: pendingFinish.track,
            sensorStats: pendingFinish.sensorStats,
            initialPhotos: pendingFinish.photos
                .where((p) => File(p.path).existsSync())
                .map(
                  (p) => CapturedPhoto(
                    file: XFile(p.path),
                    lat: p.lat,
                    lng: p.lng,
                  ),
                )
                .toList(),
            initialTitle: pendingFinish.title,
            initialDescription: pendingFinish.description,
            initialBikeId: pendingFinish.bikeId,
            recoveredCompanionUsernames: pendingFinish.companionUsernames,
            autoSave: true,
          ),
        ),
      );
      return;
    }

    final recording = await store.loadRecording();
    if (recording == null || !mounted) return;
    await _controller.resumeFromDraft(recording);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {});
    if (_controller.track.isNotEmpty) {
      final last = _controller.track.last;
      _mapController.move(
        LatLng(last.lat, last.lng),
        _mapController.camera.zoom,
      );
    }
  }

  Future<void> _start() async {
    await maybeShowBatteryOptimizationPrompt(context);
    if (!mounted) return;

    final sensorsEnabled = context.read<SensorSettingsProvider>().enabled;
    final ok = await _controller.start(
      bikeId: _selectedBike?.id,
      sensorsEnabled: sensorsEnabled,
    );
    if (!ok && mounted) {
      setState(
        () => _permissionError = AppLocalizations.of(
          context,
        )!.recordPermissionError,
      );
    }
  }

  Future<void> _pickBike() async {
    final picked = await showModalBottomSheet<Bike?>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ..._bikes.map(
              (bike) => ListTile(
                leading: const Icon(
                  Icons.two_wheeler_rounded,
                  color: RedlColors.textSecondary,
                ),
                title: Text(bike.displayName, style: RedlText.body()),
                trailing: bike.id == _selectedBike?.id
                    ? const Icon(Icons.check, color: RedlColors.accent)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(bike),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _selectedBike = picked);
  }

  Future<void> _stopAndSave() async {
    _controller.stop();

    // The backend needs at least 2 GPS points to draw a route - a ride with
    // no detected movement (e.g. stopped immediately, or GPS never got a
    // fix) can't be saved. Catch that here with a clear message instead of
    // letting the rider fill out the whole save form only to hit a raw
    // validation error from the API.
    if (_controller.track.length < 2) {
      final l10n = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: RedlColors.surface2,
          title: Text(
            l10n.noMovementTitle,
            style: RedlText.title(fontSize: 15),
          ),
          content: Text(
            l10n.noMovementMessage,
            style: RedlText.body(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionOk),
            ),
          ],
        ),
      );
      await _controller.discard();
      _controller.reset();
      return;
    }

    final rideId = await _waitForRideId();
    if (rideId == null || !mounted) return;

    final startedAt = _controller.startedAt!;
    final durationSeconds = _controller.elapsed.inSeconds;
    final distanceMeters = _controller.distanceMeters.round();
    final avgSpeedKmh = _controller.avgSpeedKmh;
    final maxSpeedKmh = _controller.maxSpeedKmh;
    final track = List.of(_controller.track);
    final initialPhotos = List.of(_controller.photos);
    final sensorStats = _controller.sensorStats;

    // Persisted before the save screen even opens, so the ride survives an
    // app kill during that screen too - not just during recording
    // (backlog BUG-2). RideSummaryScreen keeps this up to date afterward.
    final bikeId = _controller.bikeId;

    await RideDraftStore().savePendingFinish(
      RidePendingFinish(
        rideId: rideId,
        bikeId: bikeId,
        title: AppLocalizations.of(context)!.defaultRideTitle,
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        avgSpeedKmh: avgSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
        track: track,
        sensorStats: sensorStats,
        photos: initialPhotos
            .map(
              (p) => PersistedPhoto(path: p.file.path, lat: p.lat, lng: p.lng),
            )
            .toList(),
        companionUsernames: const [],
      ),
    );
    _controller.reset();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => RideSummaryScreen.save(
          rideId: rideId,
          startedAt: startedAt,
          durationSeconds: durationSeconds,
          distanceMeters: distanceMeters,
          avgSpeedKmh: avgSpeedKmh,
          maxSpeedKmh: maxSpeedKmh,
          track: track,
          initialPhotos: initialPhotos,
          sensorStats: sensorStats,
          // The rider already picked a bike at start - preselect it here
          // too, while still letting them change it (backlog FEAT-3).
          initialBikeId: bikeId,
        ),
      ),
    );
  }

  /// Waits for `POST /rides/start` to land if it hasn't yet (the ride
  /// started offline) - `finish()` needs the backend ride id. Cancelable,
  /// since the retry keeps running in the background regardless (backlog
  /// BUG-2).
  Future<int?> _waitForRideId() async {
    if (_controller.rideId != null) return _controller.rideId;

    var cancelled = false;
    void onControllerTick() {
      if (_controller.rideId != null && mounted) {
        Navigator.of(context).maybePop();
      }
    }

    _controller.addListener(onControllerTick);
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: RedlColors.surface2,
        title: Text(
          l10n.awaitingConnectionTitle,
          style: RedlText.title(fontSize: 15),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: RedlColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.awaitingConnectionMessage,
                style: RedlText.body(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.actionCancel),
          ),
        ],
      ),
    );
    _controller.removeListener(onControllerTick);
    return cancelled ? null : _controller.rideId;
  }

  Future<void> _capturePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    _controller.addPhoto(
      CapturedPhoto(
        file: photo,
        lat: _controller.lastLat,
        lng: _controller.lastLng,
      ),
    );
  }

  Future<void> _addPoi() async {
    final l10n = AppLocalizations.of(context)!;
    final titleController = TextEditingController();
    File? photo;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: RedlColors.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                RedlSpacing.screenPadding,
                20,
                RedlSpacing.screenPadding,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.poiFormTitle, style: RedlText.title(fontSize: 15)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: RedlText.body(),
                    decoration: InputDecoration(
                      labelText: l10n.poiFormTitleFieldLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: RedlSecondaryButton(
                          label: l10n.actionTakePhoto,
                          onPressed: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.camera,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              setSheetState(() => photo = File(picked.path));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RedlSecondaryButton(
                          label: l10n.actionChooseFromGallery,
                          onPressed: () async {
                            final picked = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                            );
                            if (picked != null) {
                              setSheetState(() => photo = File(picked.path));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (photo != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(RedlRadius.sm),
                      child: Image.file(photo!, height: 100, fit: BoxFit.cover),
                    ),
                  ],
                  const SizedBox(height: 20),
                  RedlPrimaryButton(
                    label: l10n.poiFormAdd,
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      unawaited(
        _controller.addPoi(title: titleController.text.trim(), photo: photo),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RedlColors.surface2,
        title: Text(l10n.discardRideTitle, style: RedlText.title(fontSize: 15)),
        content: Text(
          l10n.discardRideMessage,
          style: RedlText.body(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardRideConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.discard();
      _controller.reset();
    }
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isIdle = _controller.state == RecordingState.idle;
    final isPaused = _controller.state == RecordingState.paused;

    return PopScope(
      canPop: isIdle,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isIdle) _confirmDiscard();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(45.75, 4.85),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.besse.redl',
                  ),
                  if (_controller.track.length > 1)
                    PolylineLayer(
                      polylines: speedColoredSegments(
                        _controller.track,
                        _controller.avgSpeedKmh,
                        strokeWidth: 4,
                      ),
                    ),
                ],
              ),
            ),
            if (!isIdle)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: RedlSpacing.screenPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RecordingPill(paused: isPaused),
                    if (_controller.sensorsActive) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.sensorSettingsToggleLabel,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: RedlColors.surface0,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sensors,
                            size: 14,
                            color: RedlColors.accent,
                          ),
                        ),
                      ),
                    ],
                    if (_controller.pendingStart) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.awaitingStartSyncTooltip,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: RedlColors.surface0,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            size: 14,
                            color: RedlColors.accentTint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (isIdle)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_permissionError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: RedlColors.surface1,
                            borderRadius: BorderRadius.circular(RedlRadius.sm),
                          ),
                          child: Text(
                            _permissionError!,
                            style: RedlText.body(
                              fontSize: 12,
                              color: RedlColors.accentTint,
                            ),
                          ),
                        ),
                      ),
                    if (_bikes.length > 1) ...[
                      GestureDetector(
                        onTap: _pickBike,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: RedlColors.surface1,
                            borderRadius: BorderRadius.circular(RedlRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.two_wheeler_rounded,
                                size: 16,
                                color: RedlColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedBike?.displayName ?? l10n.bikeNone,
                                style: RedlText.body(fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.expand_more,
                                size: 16,
                                color: RedlColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    GestureDetector(
                      onTap: _start,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: RedlColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fiber_manual_record,
                          color: RedlColors.baseAlt,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.recordStartRide,
                      style: RedlText.title(fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (!isIdle)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _StatSheet(
                  controller: _controller,
                  onPauseResume: () => setState(
                    () => isPaused ? _controller.resume() : _controller.pause(),
                  ),
                  onStop: _stopAndSave,
                  onCapturePhoto: _capturePhoto,
                  onAddPoi: _addPoi,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: RedlColors.surface0,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: paused ? RedlColors.textMuted : RedlColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            paused ? l10n.pausedLabel : l10n.recordingLabel,
            style: RedlText.eyebrow(fontSize: 10, color: RedlColors.baseAlt),
          ),
        ],
      ),
    );
  }
}

class _StatSheet extends StatelessWidget {
  const _StatSheet({
    required this.controller,
    required this.onPauseResume,
    required this.onStop,
    required this.onCapturePhoto,
    required this.onAddPoi,
  });

  final RecordingController controller;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback onCapturePhoto;
  final VoidCallback onAddPoi;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isPaused = controller.state == RecordingState.paused;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: RedlColors.surface1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(
                label: l10n.statSpeed,
                value: formatSpeedKmh(controller.currentSpeedKmh),
              ),
              _StatColumn(
                label: l10n.statDistance,
                value: formatDistanceKm(controller.distanceMeters / 1000),
              ),
              _StatColumn(
                label: l10n.statTime,
                value: formatDuration(controller.elapsed),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onCapturePhoto,
                child: Tooltip(
                  message: l10n.capturePhotoTooltip,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: RedlColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: RedlColors.baseAlt,
                          size: 22,
                        ),
                        if (controller.photos.isNotEmpty)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: const BoxDecoration(
                                color: RedlColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${controller.photos.length}',
                                style: RedlText.body(
                                  fontSize: 9,
                                  color: RedlColors.baseAlt,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onAddPoi,
                child: Tooltip(
                  message: l10n.recordAddPoi,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: RedlColors.surface2,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_location_alt_outlined,
                          color: RedlColors.baseAlt,
                          size: 22,
                        ),
                      ),
                      if (controller.pendingPoiCount > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: RedlColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RedlSecondaryButton(
                  label: isPaused ? l10n.actionResume : l10n.actionPause,
                  onPressed: onPauseResume,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: RedlColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    color: RedlColors.baseAlt,
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: RedlText.statValue(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: RedlText.eyebrow(fontSize: 9)),
      ],
    );
  }
}
