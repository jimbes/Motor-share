/// One badge in the catalog (REDL project doc, section 9.2). [earnedAt] is
/// only present when this badge was fetched from the current user's own
/// earned list (`GET /me/rewards`); the full catalog (`GET /rewards`) only
/// sets [earned].
class BadgeInfo {
  const BadgeInfo({
    required this.code,
    required this.name,
    required this.description,
    this.earned = false,
    this.earnedAt,
    this.progress,
    this.threshold,
  });

  final String code;
  final String name;
  final String description;
  final bool earned;
  final DateTime? earnedAt;

  /// How far along the rider is, and the target - both only sent by the
  /// catalog, and only for badges not yet earned. Null on an earned badge,
  /// and null against a backend too old to report them.
  final int? progress;
  final int? threshold;

  /// 0..1, or null when this badge reports no progress to show.
  double? get progressRatio {
    final target = threshold;
    final current = progress;
    if (target == null || current == null || target <= 0) return null;
    return (current / target).clamp(0.0, 1.0);
  }

  factory BadgeInfo.fromCatalogJson(Map<String, dynamic> json) {
    return BadgeInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      earned: json['earned'] as bool,
      progress: (json['progress'] as num?)?.toInt(),
      threshold: (json['threshold'] as num?)?.toInt(),
    );
  }

  factory BadgeInfo.fromEarnedJson(Map<String, dynamic> json) {
    return BadgeInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      earned: true,
      earnedAt: DateTime.parse(json['earned_at'] as String),
    );
  }
}
