import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'models/ride_sensor_stats.dart';

/// Turns a stream of raw accelerometer samples into the running maxima
/// stored in [RideSensorStats] (REDL project doc, section 9.5, level 2).
///
/// This assumes the phone is mounted with its screen facing up and its
/// "up" (Y) axis pointing toward the front of the bike - a simplifying
/// assumption reasonable for a phone in a handlebar mount, but not
/// universally true. Exact detection thresholds (e.g. telling a real lean
/// from the phone shifting in a pocket) are explicitly left as a follow-up
/// in the project doc - this gives a first, honest approximation from the
/// raw accelerometer signal alone.
class SensorStatsTracker {
  static const _gravityMs2 = 9.80665;

  double _maxLeanAngleDeg = 0;
  double _maxLateralG = 0;
  double _maxAccelG = 0;
  double _maxBrakeG = 0;
  int _sampleCount = 0;

  void onData(AccelerometerEvent event) {
    _sampleCount++;

    // Roll angle away from vertical, from the gravity vector components.
    final leanAngleDeg = math.atan2(event.x.abs(), event.z.abs()) * 180 / math.pi;
    _maxLeanAngleDeg = math.max(_maxLeanAngleDeg, leanAngleDeg);

    final lateralG = event.x.abs() / _gravityMs2;
    _maxLateralG = math.max(_maxLateralG, lateralG);

    // Forward axis: positive is acceleration, negative is braking.
    final forwardG = event.y / _gravityMs2;
    if (forwardG > 0) {
      _maxAccelG = math.max(_maxAccelG, forwardG);
    } else {
      _maxBrakeG = math.max(_maxBrakeG, -forwardG);
    }
  }

  RideSensorStats? snapshot() {
    if (_sampleCount == 0) return null;

    return RideSensorStats(
      maxLeanAngleDeg: double.parse(_maxLeanAngleDeg.toStringAsFixed(1)),
      maxLateralG: double.parse(_maxLateralG.toStringAsFixed(2)),
      maxAccelG: double.parse(_maxAccelG.toStringAsFixed(2)),
      maxBrakeG: double.parse(_maxBrakeG.toStringAsFixed(2)),
      sampleCount: _sampleCount,
    );
  }
}
