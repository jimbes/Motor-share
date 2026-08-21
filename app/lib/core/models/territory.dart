/// One territory grid cell (REDL project doc, section 9.3). [ownerUserId]
/// is null for a cell no one currently holds.
class Territory {
  const Territory({
    required this.h3Index,
    required this.centerLat,
    required this.centerLng,
    this.ownerUserId,
    required this.isMine,
  });

  final String h3Index;
  final double centerLat;
  final double centerLng;
  final int? ownerUserId;
  final bool isMine;

  factory Territory.fromJson(Map<String, dynamic> json) {
    return Territory(
      h3Index: json['h3_index'] as String,
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      ownerUserId: json['owner_user_id'] as int?,
      isMine: json['is_mine'] as bool,
    );
  }
}
