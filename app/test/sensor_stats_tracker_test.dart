import 'package:flutter_test/flutter_test.dart';
import 'package:redl/core/sensor_stats_tracker.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  group('SensorStatsTracker', () {
    test('returns null when no samples were recorded', () {
      final tracker = SensorStatsTracker();
      expect(tracker.snapshot(), isNull);
    });

    test('tracks the maximum lean angle from the accelerometer x/z components', () {
      final tracker = SensorStatsTracker();
      // Upright: no lean.
      tracker.onData(AccelerometerEvent(0, 0, 9.81, DateTime.now()));
      // Leaned over: x and z roughly equal implies ~45 degrees.
      tracker.onData(AccelerometerEvent(9.81, 0, 9.81, DateTime.now()));

      final stats = tracker.snapshot()!;
      expect(stats.maxLeanAngleDeg, closeTo(45.0, 0.5));
    });

    test('separates acceleration (positive forward axis) from braking (negative)', () {
      final tracker = SensorStatsTracker();
      tracker.onData(AccelerometerEvent(0, 4.9, 9.81, DateTime.now())); // ~0.5g forward
      tracker.onData(AccelerometerEvent(0, -9.81, 9.81, DateTime.now())); // ~1g braking

      final stats = tracker.snapshot()!;
      expect(stats.maxAccelG, closeTo(0.5, 0.05));
      expect(stats.maxBrakeG, closeTo(1.0, 0.05));
    });

    test('counts every sample processed', () {
      final tracker = SensorStatsTracker();
      for (var i = 0; i < 5; i++) {
        tracker.onData(AccelerometerEvent(0, 0, 9.81, DateTime.now()));
      }

      expect(tracker.snapshot()!.sampleCount, 5);
    });
  });
}
