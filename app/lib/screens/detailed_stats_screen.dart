import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/models/ride.dart';
import '../core/models/track_point.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import '../widgets/redl_buttons.dart';
import '../widgets/redl_logo.dart';

/// Post-ride detailed statistics (REDL project doc, section 8.3.1): a
/// speed/time graph, a "Parcours" grid derived from the GPS track alone
/// (available for every ride), and a "Style de conduite" grid from the
/// optional sensor capture (project doc 9.5) - replaced by a hint to enable
/// sensors when that ride didn't have them on.
class DetailedStatsScreen extends StatelessWidget {
  const DetailedStatsScreen({super.key, required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shareBoundaryKey = GlobalKey();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detailedStatsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.shareStatsAction,
            onPressed: () => _share(context, shareBoundaryKey),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                RedlSpacing.screenPadding,
                16,
                RedlSpacing.screenPadding,
                32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 180,
                    child: _SpeedTimeChart(track: ride.track ?? ride.polyline),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.statsCourseSectionLabel, style: RedlText.eyebrow()),
                  const SizedBox(height: 10),
                  _StatsGridSection(
                    cells: [
                      (
                        l10n.statDistance,
                        formatDistanceKm(ride.distanceMeters / 1000),
                      ),
                      (
                        l10n.statDuration,
                        formatDuration(Duration(seconds: ride.durationSeconds)),
                      ),
                      (l10n.statAvgSpeed, formatSpeedKmh(ride.avgSpeedKmh)),
                      (l10n.statMaxSpeed, formatSpeedKmh(ride.maxSpeedKmh)),
                      (
                        l10n.statElevationGain,
                        ride.elevationGainM != null
                            ? '${ride.elevationGainM} m'
                            : '—',
                      ),
                      (
                        l10n.statElevationLoss,
                        ride.elevationLossM != null
                            ? '${ride.elevationLossM} m'
                            : '—',
                      ),
                      (
                        l10n.statMovingTime,
                        ride.movingTimeSeconds != null
                            ? formatDuration(
                                Duration(seconds: ride.movingTimeSeconds!),
                              )
                            : '—',
                      ),
                      (
                        l10n.statStoppedTime,
                        ride.stoppedTimeSeconds != null
                            ? formatDuration(
                                Duration(seconds: ride.stoppedTimeSeconds!),
                              )
                            : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.statsRidingStyleSectionLabel,
                    style: RedlText.eyebrow(),
                  ),
                  const SizedBox(height: 10),
                  if (ride.sensorStats != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MinMaxGaugeCard(
                          label: l10n.statLeanAngleGaugeLabel,
                          leftLabel: l10n.directionLeftLabel,
                          rightLabel: l10n.directionRightLabel,
                          leftValue: ride.sensorStats!.maxLeanAngleLeftDeg,
                          rightValue: ride.sensorStats!.maxLeanAngleRightDeg,
                          unit: '°',
                        ),
                        const SizedBox(height: 10),
                        _MinMaxGaugeCard(
                          label: l10n.statLateralGGaugeLabel,
                          leftLabel: l10n.directionLeftLabel,
                          rightLabel: l10n.directionRightLabel,
                          leftValue: ride.sensorStats!.maxLateralGLeft,
                          rightValue: ride.sensorStats!.maxLateralGRight,
                          unit: 'g',
                          decimals: 2,
                        ),
                        const SizedBox(height: 10),
                        _MinMaxGaugeCard(
                          label: l10n.statBrakeAccelGaugeLabel,
                          leftLabel: l10n.axisBrakingLabel,
                          rightLabel: l10n.axisAccelerationLabel,
                          leftValue: ride.sensorStats!.maxBrakeG,
                          rightValue: ride.sensorStats!.maxAccelG,
                          unit: 'g',
                          decimals: 2,
                        ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RedlColors.surface2,
                        borderRadius: BorderRadius.circular(RedlRadius.sm),
                      ),
                      child: Text(
                        l10n.sensorsDisabledHint,
                        style: RedlText.body(
                          fontSize: 13,
                          color: RedlColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  RedlPrimaryButton(
                    label: l10n.shareStatsAction,
                    onPressed: () => _share(context, shareBoundaryKey),
                  ),
                ],
              ),
            ),
            // Positioned far outside the viewport rather than hidden via
            // Offstage/Opacity: both of those skip painting entirely, which
            // would leave RenderRepaintBoundary.toImage() with nothing to
            // capture.
            Positioned(
              left: -3000,
              top: 0,
              child: RepaintBoundary(
                key: shareBoundaryKey,
                child: _ShareableRecapCard(ride: ride),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context, GlobalKey boundaryKey) async {
    try {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/redl_ride_${ride.id}_stats.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (_) {
      // Sharing is a convenience action - a failure here shouldn't block the screen.
    }
  }
}

/// The exportable recap card (project doc 8.3.1): dark background, REDL
/// mark, key values in the accent color. Rendered off-screen ([Offstage])
/// purely so [RenderRepaintBoundary.toImage] has something to capture -
/// the visible page has its own, denser layout above.
class _ShareableRecapCard extends StatelessWidget {
  const _ShareableRecapCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      color: RedlColors.base,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const RedlMark(size: 36, light: true),
          const SizedBox(height: 20),
          Text(
            ride.title,
            style: RedlText.title(fontSize: 18, color: RedlColors.baseAlt),
          ),
          const SizedBox(height: 20),
          _recapRow(
            l10n.statDistance,
            formatDistanceKm(ride.distanceMeters / 1000),
          ),
          _recapRow(
            l10n.statDuration,
            formatDuration(Duration(seconds: ride.durationSeconds)),
          ),
          _recapRow(l10n.statAvgSpeed, formatSpeedKmh(ride.avgSpeedKmh)),
          _recapRow(
            l10n.rideScoreLabel,
            ride.rideScore != null ? '${ride.rideScore}' : '—',
          ),
        ],
      ),
    );
  }

  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: RedlText.eyebrow(
              fontSize: 10,
              color: RedlColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: RedlText.statValue(fontSize: 16, color: RedlColors.accent),
          ),
        ],
      ),
    );
  }
}

/// A two-sided min/max bar for a "Style de conduite" stat whose two poles
/// (left/right lean, braking/acceleration, ...) come from the same signed
/// axis - one number for each direction rather than a single aggregate
/// (backlog FEAT-1). The bar auto-scales to whichever side reached
/// further this ride, so a mild ride and a spirited one both fill the
/// card meaningfully instead of always maxing out or barely showing.
class _MinMaxGaugeCard extends StatelessWidget {
  const _MinMaxGaugeCard({
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftValue,
    required this.rightValue,
    required this.unit,
    this.decimals = 0,
  });

  final String label;
  final String leftLabel;
  final String rightLabel;
  final double? leftValue;
  final double? rightValue;
  final String unit;
  final int decimals;

  String _format(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(decimals)}$unit';

  @override
  Widget build(BuildContext context) {
    final left = leftValue ?? 0;
    final right = rightValue ?? 0;
    final scale = math.max(math.max(left, right), 0.001);
    final leftFraction = (left / scale).clamp(0.0, 1.0);
    final rightFraction = (right / scale).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RedlColors.surface2,
        borderRadius: BorderRadius.circular(RedlRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: RedlText.eyebrow(fontSize: 9)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(leftValue), style: RedlText.statValue(fontSize: 16)),
              Text(
                _format(rightValue),
                style: RedlText.statValue(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: leftFraction,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: RedlColors.textSecondary,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 2, height: 14, color: RedlColors.textMuted),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: rightFraction,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: RedlColors.accent,
                          borderRadius: BorderRadius.horizontal(
                            right: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                leftLabel,
                style: RedlText.body(fontSize: 9, color: RedlColors.textMuted),
              ),
              Text(
                rightLabel,
                style: RedlText.body(fontSize: 9, color: RedlColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsGridSection extends StatelessWidget {
  const _StatsGridSection({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: cells
          .map(
            (c) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RedlColors.surface2,
                borderRadius: BorderRadius.circular(RedlRadius.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(c.$1, style: RedlText.eyebrow(fontSize: 9)),
                  const SizedBox(height: 6),
                  Text(c.$2, style: RedlText.statValue(fontSize: 18)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// A minimal speed/time line chart drawn directly with a [CustomPainter] -
/// no charting dependency needed for a single line.
class _SpeedTimeChart extends StatelessWidget {
  const _SpeedTimeChart({required this.track});

  final List<TrackPoint> track;

  @override
  Widget build(BuildContext context) {
    final points = <Offset>[];
    DateTime? firstT;
    var maxSpeed = 1.0;

    for (final p in track) {
      final speed = p.speed ?? 0.0;
      final tRaw = p.t;
      if (tRaw == null) continue;
      final t = DateTime.tryParse(tRaw);
      if (t == null) continue;
      firstT ??= t;
      final elapsed = t.difference(firstT).inSeconds.toDouble();
      maxSpeed = speed > maxSpeed ? speed : maxSpeed;
      points.add(Offset(elapsed, speed));
    }

    if (points.length < 2) {
      return Center(
        child: Text('—', style: RedlText.body(color: RedlColors.textMuted)),
      );
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _SpeedTimePainter(
        points: points,
        maxSpeed: maxSpeed,
        maxTime: points.last.dx == 0 ? 1 : points.last.dx,
      ),
    );
  }
}

class _SpeedTimePainter extends CustomPainter {
  _SpeedTimePainter({
    required this.points,
    required this.maxSpeed,
    required this.maxTime,
  });

  final List<Offset> points;
  final double maxSpeed;
  final double maxTime;

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = RedlColors.textMuted.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    final linePaint = Paint()
      ..color = RedlColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (points[i].dx / maxTime) * size.width;
      final y = size.height - (points[i].dy / maxSpeed) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedTimePainter oldDelegate) =>
      oldDelegate.points != points;
}
