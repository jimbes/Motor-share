import 'badge_info.dart';

/// The authenticated rider's own XP/level/badges/territory count
/// (`GET /me/rewards`) - powers the rewards block on the profile screen.
class RewardSummary {
  const RewardSummary({
    required this.xpTotal,
    required this.level,
    required this.territoriesOwnedCount,
    required this.badges,
  });

  final int xpTotal;
  final int level;
  final int territoriesOwnedCount;
  final List<BadgeInfo> badges;

  factory RewardSummary.fromJson(Map<String, dynamic> json) {
    return RewardSummary(
      xpTotal: json['xp_total'] as int,
      level: json['level'] as int,
      territoriesOwnedCount: json['territories_owned_count'] as int,
      badges: (json['badges'] as List<dynamic>)
          .map((e) => BadgeInfo.fromEarnedJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The XP/level/badge consequences of finishing one ride, returned inline
/// by `PATCH /rides/{id}/finish` alongside the ride itself.
class RideRewardOutcome {
  const RideRewardOutcome({
    required this.xpGained,
    required this.level,
    required this.leveledUp,
    required this.territoryCellsTouched,
    required this.newBadges,
  });

  final int xpGained;
  final int level;
  final bool leveledUp;
  final int territoryCellsTouched;
  final List<BadgeInfo> newBadges;

  factory RideRewardOutcome.fromJson(Map<String, dynamic> json) {
    return RideRewardOutcome(
      xpGained: json['xp_gained'] as int,
      level: json['level'] as int,
      leveledUp: json['leveled_up'] as bool,
      territoryCellsTouched: json['territory_cells_touched'] as int,
      newBadges: (json['new_badges'] as List<dynamic>)
          .map(
            (e) => BadgeInfo.fromCatalogJson({
              ...e as Map<String, dynamic>,
              'earned': true,
            }),
          )
          .toList(),
    );
  }
}
