import 'package:flutter_test/flutter_test.dart';

import 'package:redl/core/models/track_point.dart';
import 'package:redl/core/ride_chart_series.dart';

/// Roughly 111 m of northward step per 0.001 degree of latitude, so a
/// track built this way has a distance that is easy to reason about.
List<TrackPoint> _track(
  int count, {
  double? Function(int)? speed,
  double? Function(int)? alt,
}) {
  return [
    for (var i = 0; i < count; i++)
      TrackPoint(
        lat: 45.0 + i * 0.001,
        lng: 5.0,
        speed: speed?.call(i),
        alt: alt?.call(i),
      ),
  ];
}

void main() {
  group('buildSpeedOverDistanceSeries', () {
    test('plots each sample against the distance travelled so far', () {
      final series = buildSpeedOverDistanceSeries(
        _track(3, speed: (i) => 40.0 + i * 10),
      )!;

      expect(series.points, hasLength(3));
      expect(series.points.first.distanceKm, 0);
      expect(series.points.map((p) => p.value), [40, 50, 60]);
      // Three points, two ~111 m steps.
      expect(series.totalDistanceKm, closeTo(0.222, 0.005));
    });

    test('reports the value bounds a chart needs for its axis', () {
      final series = buildSpeedOverDistanceSeries(
        _track(4, speed: (i) => [30.0, 90.0, 12.0, 45.0][i]),
      )!;

      expect(series.minValue, 12);
      expect(series.maxValue, 90);
    });

    test('distance keeps advancing across samples with no speed recorded', () {
      // A gap in speed data must not shorten the x-axis: the rider still
      // covered that ground.
      final withGap = buildSpeedOverDistanceSeries(
        _track(4, speed: (i) => i == 1 ? null : 50.0),
      )!;
      final withoutGap = buildSpeedOverDistanceSeries(
        _track(4, speed: (i) => 50.0),
      )!;

      expect(withGap.points, hasLength(3));
      expect(withGap.totalDistanceKm, closeTo(withoutGap.totalDistanceKm, 1e-9));
      expect(withGap.points.last.distanceKm, closeTo(withoutGap.points.last.distanceKm, 1e-9));
    });

    test('is null for a track with no speed samples at all', () {
      expect(buildSpeedOverDistanceSeries(_track(10)), isNull);
    });

    test('is null for a track too short to draw a line', () {
      expect(buildSpeedOverDistanceSeries(_track(1, speed: (_) => 50.0)), isNull);
    });

    test('caps how many points it plots on a long ride', () {
      // A couple of hours at one sample every two seconds.
      final series = buildSpeedOverDistanceSeries(
        _track(3600, speed: (i) => 50.0 + (i % 10)),
      )!;

      expect(series.points.length, lessThanOrEqualTo(400));
      // Downsampling must not shorten the route: 3599 steps of ~111.3 m.
      expect(series.totalDistanceKm, closeTo(400.6, 0.5));
    });

    test('keeps the curve spanning the whole ride after downsampling', () {
      final series = buildSpeedOverDistanceSeries(
        _track(2000, speed: (i) => i.toDouble()),
      )!;

      expect(series.points.first.distanceKm, lessThan(series.totalDistanceKm * 0.02));
      expect(series.points.last.distanceKm, greaterThan(series.totalDistanceKm * 0.98));
      // Averaged buckets stay monotonic for a monotonic input.
      final values = series.points.map((p) => p.value).toList();
      expect(values, orderedEquals(List.of(values)..sort()));
    });
  });

  group('buildElevationOverDistanceSeries', () {
    test('plots altitude against distance', () {
      // Shorter than the smoothing window, so the samples pass through
      // untouched - smoothing never runs on a track it can't fill.
      final series = buildElevationOverDistanceSeries(
        _track(3, alt: (i) => 200.0 + i * 10),
      )!;

      expect(series.points, hasLength(3));
      expect(series.points.map((p) => p.value), [200, 210, 220]);
      expect(series.points.first.distanceKm, 0);
    });

    test('smooths the single-sample GPS spikes that jag a flat profile', () {
      // A flat 300 m road with one 80 m glitch - the kind consumer GPS
      // altitude produces regularly.
      final series = buildElevationOverDistanceSeries(
        _track(11, alt: (i) => i == 5 ? 380.0 : 300.0),
      )!;

      expect(series.maxValue, lessThan(340));
      expect(series.maxValue, greaterThan(300));
    });

    test('is null for a track with no altitude samples', () {
      expect(buildElevationOverDistanceSeries(_track(10, speed: (_) => 50.0)), isNull);
    });
  });
}
