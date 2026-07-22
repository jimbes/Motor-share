import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../state/recording_controller.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/redl_buttons.dart';
import 'ride_summary_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _controller = RecordingController();
  final _mapController = MapController();
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
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
      _mapController.move(LatLng(last.lat, last.lng), _mapController.camera.zoom);
    }
  }

  Future<void> _start() async {
    final ok = await _controller.start();
    if (!ok && mounted) {
      setState(() => _permissionError = 'Location permission is needed to record a ride.');
    }
  }

  Future<void> _stopAndSave() async {
    _controller.stop();
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => RideSummaryScreen.save(
          startedAt: _controller.startedAt!,
          durationSeconds: _controller.elapsed.inSeconds,
          distanceMeters: _controller.distanceMeters.round(),
          avgSpeedKmh: _controller.avgSpeedKmh,
          maxSpeedKmh: _controller.maxSpeedKmh,
          track: List.of(_controller.track),
        ),
      ),
    );
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = _controller.state == RecordingState.idle;
    final isPaused = _controller.state == RecordingState.paused;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(initialCenter: LatLng(45.75, 4.85), initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.redl.app',
                ),
                if (_controller.track.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _controller.track.map((p) => LatLng(p.lat, p.lng)).toList(),
                        color: RedlColors.accent,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (!isIdle)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: RedlSpacing.screenPadding,
              child: _RecordingPill(paused: isPaused),
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
                        decoration: BoxDecoration(color: RedlColors.surface1, borderRadius: BorderRadius.circular(RedlRadius.sm)),
                        child: Text(_permissionError!, style: RedlText.body(fontSize: 12, color: RedlColors.accentTint)),
                      ),
                    ),
                  GestureDetector(
                    onTap: _start,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(color: RedlColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.fiber_manual_record, color: RedlColors.baseAlt, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Start Ride', style: RedlText.title(fontSize: 13)),
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
                onPauseResume: () => setState(() => isPaused ? _controller.resume() : _controller.pause()),
                onStop: _stopAndSave,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordingPill extends StatelessWidget {
  const _RecordingPill({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: RedlColors.surface0, borderRadius: BorderRadius.circular(RedlRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: paused ? RedlColors.textMuted : RedlColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(paused ? 'PAUSED' : 'RECORDING', style: RedlText.eyebrow(fontSize: 10, color: RedlColors.baseAlt)),
        ],
      ),
    );
  }
}

class _StatSheet extends StatelessWidget {
  const _StatSheet({required this.controller, required this.onPauseResume, required this.onStop});

  final RecordingController controller;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final isPaused = controller.state == RecordingState.paused;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).padding.bottom + 20),
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
              _StatColumn(label: 'SPEED', value: formatSpeedKmh(controller.currentSpeedKmh)),
              _StatColumn(label: 'DISTANCE', value: formatDistanceKm(controller.distanceMeters / 1000)),
              _StatColumn(label: 'TIME', value: formatDuration(controller.elapsed)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: RedlSecondaryButton(label: isPaused ? 'Resume' : 'Pause', onPressed: onPauseResume)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onStop,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: RedlColors.accent, shape: BoxShape.circle),
                  child: const Icon(Icons.stop_rounded, color: RedlColors.baseAlt, size: 26),
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
