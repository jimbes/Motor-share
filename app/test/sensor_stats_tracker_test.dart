import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/sensor_stats_tracker.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// A synthetic accelerometer sample for a phone tilted [angleDeg] from
/// vertical (screen-up, gravity-only - no real ride dynamics).
AccelerometerEvent _tiltedSample(double angleDeg) {
  final angleRad = angleDeg * math.pi / 180;
  return AccelerometerEvent(
    9.81 * math.sin(angleRad),
    0,
    9.81 * math.cos(angleRad),
    DateTime.now(),
  );
}

void main() {
  group('SensorStatsTracker', () {
    test('returns null when no samples were recorded', () {
      final tracker = SensorStatsTracker();
      expect(tracker.snapshot(), isNull);
    });

    test(
      'a lean is measured relative to the first sample, not a fixed vertical',
      () {
        final tracker = SensorStatsTracker();
        // Calibration sample: the mount itself sits 10 degrees off flat -
        // that becomes the new zero, not literally-vertical.
        tracker.onData(_tiltedSample(10));
        // A further 45-degree lean from that calibrated zero.
        tracker.onData(_tiltedSample(55));

        final stats = tracker.snapshot()!;
        expect(stats.maxLeanAngleRightDeg, closeTo(45.0, 0.5));
        expect(stats.maxLeanAngleLeftDeg, 0);
      },
    );

    test(
      'the same physical lean reads the same regardless of the mount offset calibrated away',
      () {
        final flatMount = SensorStatsTracker()
          ..onData(_tiltedSample(0))
          ..onData(_tiltedSample(45));

        final offsetMount = SensorStatsTracker()
          ..onData(_tiltedSample(10))
          ..onData(_tiltedSample(55));

        expect(
          offsetMount.snapshot()!.maxLeanAngleRightDeg,
          closeTo(flatMount.snapshot()!.maxLeanAngleRightDeg!, 0.5),
        );
      },
    );

    test(
      'separates a left lean from a right lean instead of only tracking magnitude',
      () {
        final tracker = SensorStatsTracker();
        tracker.onData(_tiltedSample(0)); // calibrates upright
        tracker.onData(_tiltedSample(45)); // 45 degrees right
        tracker.onData(_tiltedSample(-45)); // 45 degrees left

        final stats = tracker.snapshot()!;
        expect(stats.maxLeanAngleRightDeg, closeTo(45.0, 0.5));
        expect(stats.maxLeanAngleLeftDeg, closeTo(45.0, 0.5));
      },
    );

    test(
      'separates acceleration (positive forward axis) from braking (negative)',
      () {
        final tracker = SensorStatsTracker();
        tracker.onData(
          AccelerometerEvent(0, 4.9, 9.81, DateTime.now()),
        ); // ~0.5g forward
        tracker.onData(
          AccelerometerEvent(0, -9.81, 9.81, DateTime.now()),
        ); // ~1g braking

        final stats = tracker.snapshot()!;
        expect(stats.maxAccelG, closeTo(0.5, 0.05));
        expect(stats.maxBrakeG, closeTo(1.0, 0.05));
      },
    );

    test('counts every sample processed', () {
      final tracker = SensorStatsTracker();
      for (var i = 0; i < 5; i++) {
        tracker.onData(AccelerometerEvent(0, 0, 9.81, DateTime.now()));
      }

      expect(tracker.snapshot()!.sampleCount, 5);
    });
  });
}
