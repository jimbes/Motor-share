/// Accelerometer/gyroscope-derived maxima for a ride (REDL project doc,
/// section 9.5). Absent entirely when the rider didn't enable sensor
/// capture for that ride.
class RideSensorStats {
  const RideSensorStats({
    this.maxLeanAngleLeftDeg,
    this.maxLeanAngleRightDeg,
    this.maxLateralG,
    this.maxAccelG,
    this.maxBrakeG,
    this.sampleCount,
  });

  /// Both are unsigned magnitudes ("how far left"/"how far right"), not a
  /// single signed value - avoids baking in a left/right sign convention
  /// that a consumer would have to know about (backlog BUG-3).
  final double? maxLeanAngleLeftDeg;
  final double? maxLeanAngleRightDeg;
  final double? maxLateralG;
  final double? maxAccelG;
  final double? maxBrakeG;
  final int? sampleCount;

  Map<String, dynamic> toJson() => {
    if (maxLeanAngleLeftDeg != null)
      'max_lean_angle_left_deg': maxLeanAngleLeftDeg,
    if (maxLeanAngleRightDeg != null)
      'max_lean_angle_right_deg': maxLeanAngleRightDeg,
    if (maxLateralG != null) 'max_lateral_g': maxLateralG,
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
      maxLateralG: (json['max_lateral_g'] as num?)?.toDouble(),
      maxAccelG: (json['max_accel_g'] as num?)?.toDouble(),
      maxBrakeG: (json['max_brake_g'] as num?)?.toDouble(),
      sampleCount: json['sample_count'] as int?,
    );
  }
}
