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
  });

  final String code;
  final String name;
  final String description;
  final bool earned;
  final DateTime? earnedAt;

  factory BadgeInfo.fromCatalogJson(Map<String, dynamic> json) {
    return BadgeInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      earned: json['earned'] as bool,
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
