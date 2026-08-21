/// Accelerometer/gyroscope-derived maxima for a ride (REDL project doc,
/// section 9.5). Absent entirely when the rider didn't enable sensor
/// capture for that ride.
class RideSensorStats {
  const RideSensorStats({
    this.maxLeanAngleDeg,
    this.maxLateralG,
    this.maxAccelG,
    this.maxBrakeG,
    this.sampleCount,
  });

  final double? maxLeanAngleDeg;
  final double? maxLateralG;
  final double? maxAccelG;
  final double? maxBrakeG;
  final int? sampleCount;

  Map<String, dynamic> toJson() => {
    if (maxLeanAngleDeg != null) 'max_lean_angle_deg': maxLeanAngleDeg,
    if (maxLateralG != null) 'max_lateral_g': maxLateralG,
    if (maxAccelG != null) 'max_accel_g': maxAccelG,
    if (maxBrakeG != null) 'max_brake_g': maxBrakeG,
    if (sampleCount != null) 'sample_count': sampleCount,
  };

  factory RideSensorStats.fromJson(Map<String, dynamic> json) {
    return RideSensorStats(
      maxLeanAngleDeg: (json['max_lean_angle_deg'] as num?)?.toDouble(),
      maxLateralG: (json['max_lateral_g'] as num?)?.toDouble(),
      maxAccelG: (json['max_accel_g'] as num?)?.toDouble(),
      maxBrakeG: (json['max_brake_g'] as num?)?.toDouble(),
      sampleCount: json['sample_count'] as int?,
    );
  }
}
