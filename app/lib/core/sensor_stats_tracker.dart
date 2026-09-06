import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'models/ride_sensor_stats.dart';

/// Turns a stream of raw accelerometer samples into the running stats
/// stored in [RideSensorStats] (REDL project doc, section 9.5, level 2) -
/// a running maximum for lean angle/braking/acceleration, and the 95th
/// percentile for cornering g-force (backlog FEAT-2), which is less
/// skewed by a single unrepresentative spike (e.g. sensors left on in a
/// car, hitting a pothole) than a raw max.
///
/// This assumes the phone is mounted with its screen facing up and its
/// "up" (Y) axis pointing toward the front of the bike - a simplifying
/// assumption reasonable for a phone in a handlebar mount, but not
/// universally true. The first sample calibrates the mount's actual "no
/// lean" orientation (see [_baselineAngleDeg]), so a mount that isn't
/// perfectly flat doesn't skew every reading. Exact detection thresholds
/// (e.g. telling a real lean from the phone shifting in a pocket) are
/// explicitly left as a follow-up in the project doc - this gives a first,
/// honest approximation from the raw accelerometer signal alone.
class SensorStatsTracker {
  static const _gravityMs2 = 9.80665;

  /// The roll angle (from x/z) of the very first sample - calibrates "no
  /// lean" to however the phone actually sits in its mount, instead of
  /// assuming it's perfectly flat/vertical (backlog BUG-3). Every later
  /// sample's lean is measured relative to this, and its sign (left vs.
  /// right) is preserved instead of being discarded via `.abs()`.
  double? _baselineAngleDeg;

  double _maxLeanAngleLeftDeg = 0;
  double _maxLeanAngleRightDeg = 0;
  double _maxAccelG = 0;
  double _maxBrakeG = 0;
  int _sampleCount = 0;

  /// Every cornering g-force sample, kept so the 95th percentile can be
  /// computed at the end of the ride instead of the raw max (backlog
  /// FEAT-2) - a lone spike (e.g. sensors left on in a car, a pothole)
  /// would otherwise dominate an entire ride's reading.
  final List<double> _lateralGLeftSamples = [];
  final List<double> _lateralGRightSamples = [];

  void onData(AccelerometerEvent event) {
    _sampleCount++;

    final rawAngleDeg = math.atan2(event.x, event.z) * 180 / math.pi;
    if (_baselineAngleDeg == null) {
      _baselineAngleDeg = rawAngleDeg;
    } else {
      final leanDeg = _normalizeAngleDeg(rawAngleDeg - _baselineAngleDeg!);
      // The cornering g-force shares the same lean direction, so it's
      // attributed to left/right the same way (backlog FEAT-1).
      final lateralG = event.x.abs() / _gravityMs2;
      if (leanDeg >= 0) {
        _maxLeanAngleRightDeg = math.max(_maxLeanAngleRightDeg, leanDeg);
        _lateralGRightSamples.add(lateralG);
      } else {
        _maxLeanAngleLeftDeg = math.max(_maxLeanAngleLeftDeg, -leanDeg);
        _lateralGLeftSamples.add(lateralG);
      }
    }

    // Forward axis: positive is acceleration, negative is braking.
    final forwardG = event.y / _gravityMs2;
    if (forwardG > 0) {
      _maxAccelG = math.max(_maxAccelG, forwardG);
    } else {
      _maxBrakeG = math.max(_maxBrakeG, -forwardG);
    }
  }

  /// Wraps to (-180, 180] so a lean measured across the ±180° seam (e.g.
  /// baseline near 179°, sample near -179°) doesn't read as a ~358° swing.
  double _normalizeAngleDeg(double deg) {
    var normalized = deg % 360;
    if (normalized > 180) normalized -= 360;
    if (normalized < -180) normalized += 360;
    return normalized;
  }

  /// The 95th percentile of [samples] (nearest-rank method), or 0 if empty.
  double _percentile95(List<double> samples) {
    if (samples.isEmpty) return 0;
    final sorted = List<double>.of(samples)..sort();
    final rank = ((sorted.length - 1) * 0.95).round();
    return sorted[rank];
  }

  RideSensorStats? snapshot() {
    if (_sampleCount == 0) return null;

    return RideSensorStats(
      maxLeanAngleLeftDeg: double.parse(
        _maxLeanAngleLeftDeg.toStringAsFixed(1),
      ),
      maxLeanAngleRightDeg: double.parse(
        _maxLeanAngleRightDeg.toStringAsFixed(1),
      ),
      lateralGLeftP95: double.parse(
        _percentile95(_lateralGLeftSamples).toStringAsFixed(2),
      ),
      lateralGRightP95: double.parse(
        _percentile95(_lateralGRightSamples).toStringAsFixed(2),
      ),
      maxAccelG: double.parse(_maxAccelG.toStringAsFixed(2)),
      maxBrakeG: double.parse(_maxBrakeG.toStringAsFixed(2)),
      sampleCount: _sampleCount,
    );
  }
}
