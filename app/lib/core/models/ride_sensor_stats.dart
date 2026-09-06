/// Accelerometer/gyroscope-derived stats for a ride (REDL project doc,
/// section 9.5). Absent entirely when the rider didn't enable sensor
/// capture for that ride.
class RideSensorStats {
  const RideSensorStats({
    this.maxLeanAngleLeftDeg,
    this.maxLeanAngleRightDeg,
    this.lateralGLeftP95,
    this.lateralGRightP95,
    this.maxAccelG,
    this.maxBrakeG,
    this.sampleCount,
  });

  /// Unsigned magnitudes ("how far left"/"how far right"), not a single
  /// signed value - avoids baking in a left/right sign convention that a
  /// consumer would have to know about (backlog BUG-3, FEAT-1).
  final double? maxLeanAngleLeftDeg;
  final double? maxLeanAngleRightDeg;

  /// The 95th percentile (not the raw max) of cornering g-force samples,
  /// so a single unrepresentative spike doesn't dominate the whole ride's
  /// reading (backlog FEAT-2).
  final double? lateralGLeftP95;
  final double? lateralGRightP95;
  final double? maxAccelG;
  final double? maxBrakeG;
  final int? sampleCount;

  Map<String, dynamic> toJson() => {
    if (maxLeanAngleLeftDeg != null)
      'max_lean_angle_left_deg': maxLeanAngleLeftDeg,
    if (maxLeanAngleRightDeg != null)
      'max_lean_angle_right_deg': maxLeanAngleRightDeg,
    if (lateralGLeftP95 != null) 'lateral_g_left_p95': lateralGLeftP95,
    if (lateralGRightP95 != null) 'lateral_g_right_p95': lateralGRightP95,
    if (maxAccelG != null) 'max_accel_g': maxAccelG,
    if (maxBrakeG != null) 'max_brake_g': maxBrakeG,
    if (sampleCount != null) 'sample_count': sampleCount,
  };

  factory RideSensorStats.fromJson(Map<String, dynamic> json) {
    return RideSensorStats(
      maxLeanAngleLeftDeg: (json['max_lean_angle_left_deg'] as num?)
          ?.toDouble(),
      maxLeanAngleRightDeg: (json['max_lean_angle_right_deg'] as num?)
          ?.toDouble(),
      lateralGLeftP95: (json['lateral_g_left_p95'] as num?)?.toDouble(),
      lateralGRightP95: (json['lateral_g_right_p95'] as num?)?.toDouble(),
      maxAccelG: (json['max_accel_g'] as num?)?.toDouble(),
      maxBrakeG: (json['max_brake_g'] as num?)?.toDouble(),
      sampleCount: json['sample_count'] as int?,
    );
  }
}
