import 'dart:math' as math;

import 'models/track_point.dart';

/// One plotted sample: [distanceKm] along the route against [value].
class RideChartPoint {
  const RideChartPoint({required this.distanceKm, required this.value});

  final double distanceKm;
  final double value;
}

/// A metric ready to plot against distance travelled, with the bounds a
/// chart needs to lay out its axes.
class RideChartSeries {
  const RideChartSeries({
    required this.points,
    required this.minValue,
    required this.maxValue,
    required this.totalDistanceKm,
  });

  final List<RideChartPoint> points;
  final double minValue;
  final double maxValue;
  final double totalDistanceKm;
}

/// Above this, samples are averaged into buckets before plotting. A ride
/// records a point every couple of seconds, so a long one carries several
/// thousand - far more than a few hundred pixels of chart can show, and
/// enough to make touch tracking crawl.
const _maxPlottedPoints = 400;

/// Window used to smooth GPS altitude. Consumer GPS altitude is noisy
/// enough to turn a flat road into a saw blade; a short odd-sized window
/// settles it without inventing or flattening real climbs.
const _elevationSmoothingWindow = 5;

/// Speed in km/h against distance travelled. Null when the track carries no
/// usable speed samples (older rides recorded before speed was stored).
RideChartSeries? buildSpeedOverDistanceSeries(List<TrackPoint> track) {
  return _build(track, (point) => point.speed);
}

/// Altitude in metres against distance travelled, lightly smoothed. Null
/// when the track carries no altitude samples.
RideChartSeries? buildElevationOverDistanceSeries(List<TrackPoint> track) {
  final series = _build(track, (point) => point.alt);
  if (series == null) return series;

  final smoothed = _movingAverage(
    series.points.map((p) => p.value).toList(),
    _elevationSmoothingWindow,
  );

  final points = <RideChartPoint>[
    for (var i = 0; i < smoothed.length; i++)
      RideChartPoint(distanceKm: series.points[i].distanceKm, value: smoothed[i]),
  ];

  return RideChartSeries(
    points: points,
    minValue: smoothed.reduce(math.min),
    maxValue: smoothed.reduce(math.max),
    totalDistanceKm: series.totalDistanceKm,
  );
}

RideChartSeries? _build(
  List<TrackPoint> track,
  double? Function(TrackPoint) valueOf,
) {
  final samples = <RideChartPoint>[];
  var distanceMeters = 0.0;
  TrackPoint? previous;

  for (final point in track) {
    if (previous != null) {
      distanceMeters += _distanceMeters(previous, point);
    }
    previous = point;

    final value = valueOf(point);
    if (value == null) continue;

    samples.add(
      RideChartPoint(distanceKm: distanceMeters / 1000, value: value),
    );
  }

  // A single sample draws no line, and a flat route would give every
  // bucket the same x - either way there is no curve to show.
  if (samples.length < 2) return null;

  final plotted = _downsample(samples, _maxPlottedPoints);
  final values = plotted.map((p) => p.value);

  return RideChartSeries(
    points: plotted,
    minValue: values.reduce(math.min),
    maxValue: values.reduce(math.max),
    totalDistanceKm: distanceMeters / 1000,
  );
}

/// Averages samples into [limit] evenly sized buckets. Averaging rather
/// than dropping every nth sample keeps the shape of the curve honest; it
/// does mean a plotted peak can sit slightly under the ride's recorded
/// maximum, which is why the exact figures stay in the stat grid rather
/// than being read off the curve.
List<RideChartPoint> _downsample(List<RideChartPoint> samples, int limit) {
  if (samples.length <= limit) return samples;

  final bucketSize = samples.length / limit;
  final result = <RideChartPoint>[];

  for (var i = 0; i < limit; i++) {
    final start = (i * bucketSize).floor();
    final end = math.min(((i + 1) * bucketSize).floor(), samples.length);
    if (end <= start) continue;

    var distanceSum = 0.0;
    var valueSum = 0.0;
    for (var j = start; j < end; j++) {
      distanceSum += samples[j].distanceKm;
      valueSum += samples[j].value;
    }

    final count = end - start;
    result.add(
      RideChartPoint(
        distanceKm: distanceSum / count,
        value: valueSum / count,
      ),
    );
  }

  return result;
}

List<double> _movingAverage(List<double> values, int window) {
  if (values.length < window) return values;

  final half = window ~/ 2;
  return [
    for (var i = 0; i < values.length; i++)
      () {
        final start = math.max(0, i - half);
        final end = math.min(values.length, i + half + 1);
        var sum = 0.0;
        for (var j = start; j < end; j++) {
          sum += values[j];
        }
        return sum / (end - start);
      }(),
  ];
}

/// Haversine, matching how the recorder accumulates a ride's distance so
/// the chart's x-axis ends where the ride's distance figure does.
double _distanceMeters(TrackPoint a, TrackPoint b) {
  const earthRadius = 6378137.0;
  final dLat = _toRadians(b.lat - a.lat);
  final dLng = _toRadians(b.lng - a.lng);

  final h = math.pow(math.sin(dLat / 2), 2) +
      math.pow(math.sin(dLng / 2), 2) *
          math.cos(_toRadians(a.lat)) *
          math.cos(_toRadians(b.lat));

  return earthRadius * 2 * math.asin(math.sqrt(h));
}

double _toRadians(double degrees) => degrees * math.pi / 180;
