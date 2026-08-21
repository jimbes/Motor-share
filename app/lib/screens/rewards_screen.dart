import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/badge_info.dart';
import '../core/models/reward_summary.dart';
import '../core/repositories/reward_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'badge_catalog_screen.dart';
import 'territory_map_screen.dart';

/// XP per level (config/gamification.php `xp.per_level`) - level n is reached
/// at n * this value, so progress within the current level is
/// `xpTotal % xpPerLevel`.
const _xpPerLevel = 1000;

/// Dedicated rewards/progress page (beyond the compact inline block on the
/// profile screen): level/XP progress, territories owned, and every earned
/// badge with its date, plus a link to the full catalog.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  RewardSummary? _rewards;
  int? _totalBadgeCount;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });
    try {
      final repo = context.read<RewardRepository>();
      final results = await Future.wait([repo.mine(), repo.catalog()]);
      final rewards = results[0] as RewardSummary;
      final catalog = results[1] as List<BadgeInfo>;
      if (mounted) {
        setState(() {
          _rewards = rewards;
          _totalBadgeCount = catalog.length;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.rewardsScreenTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: RedlColors.accent))
            : _hasError || _rewards == null
                ? _ErrorState(message: l10n.rewardsLoadError, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        RedlSpacing.screenPadding,
                        12,
                        RedlSpacing.screenPadding,
                        24,
                      ),
                      children: [
                        _LevelCard(rewards: _rewards!),
                        const SizedBox(height: 20),
                        _TerritoriesCard(rewards: _rewards!),
                        const SizedBox(height: 24),
                        _BadgesSection(
                          rewards: _rewards!,
                          totalBadgeCount: _totalBadgeCount ?? _rewards!.badges.length,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.rewards});

  final RewardSummary rewards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final xpIntoLevel = rewards.xpTotal % _xpPerLevel;
    final remaining = _xpPerLevel - xpIntoLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: RedlColors.surface1, borderRadius: BorderRadius.circular(RedlRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rewardsLevelLabel(rewards.level), style: RedlText.wordmark(fontSize: 26)),
          const SizedBox(height: 4),
          Text(l10n.rewardsXpTotalLabel(rewards.xpTotal), style: RedlText.meta()),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: xpIntoLevel / _xpPerLevel,
              minHeight: 8,
              backgroundColor: RedlColors.surface3,
              color: RedlColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.rewardsNextLevelLabel(remaining, rewards.level + 1),
            style: RedlText.meta(color: RedlColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TerritoriesCard extends StatelessWidget {
  const _TerritoriesCard({required this.rewards});

  final RewardSummary rewards;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TerritoryMapScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: RedlColors.surface1, borderRadius: BorderRadius.circular(RedlRadius.md)),
        child: Row(
          children: [
            const Icon(Icons.hexagon_outlined, color: RedlColors.accent, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.rewardsTerritoriesSectionTitle, style: RedlText.eyebrow()),
                  const SizedBox(height: 4),
                  Text(
                    l10n.rewardsTerritoriesOwnedLabel(rewards.territoriesOwnedCount),
                    style: RedlText.title(fontSize: 16),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: RedlColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _BadgesSection extends StatelessWidget {
  const _BadgesSection({required this.rewards, required this.totalBadgeCount});

  final RewardSummary rewards;
  final int totalBadgeCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final badges = rewards.badges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.rewardsBadgesSectionTitle, style: RedlText.eyebrow()),
            Text('${badges.length} / $totalBadgeCount', style: RedlText.meta()),
          ],
        ),
        const SizedBox(height: 12),
        if (badges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l10n.rewardsNoBadgesYet, style: RedlText.body(color: RedlColors.textSecondary)),
          )
        else
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: badges.map((badge) => _EarnedBadgeTile(badge: badge)).toList(),
          ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BadgeCatalogScreen())),
          child: Text(l10n.rewardsViewFullCatalogAction, style: RedlText.body(fontSize: 13, color: RedlColors.textSecondary)),
        ),
      ],
    );
  }
}

class _EarnedBadgeTile extends StatelessWidget {
  const _EarnedBadgeTile({required this.badge});

  final BadgeInfo badge;

  void _showDetail(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(RedlSpacing.screenPadding, 20, RedlSpacing.screenPadding, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.military_tech, color: RedlColors.accent, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(badge.name, style: RedlText.title(fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(badge.description, style: RedlText.body(color: RedlColors.textSecondary)),
                if (badge.earnedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    l10n.badgeEarnedOnLabel('${badge.earnedAt!.day}/${badge.earnedAt!.month}/${badge.earnedAt!.year}'),
                    style: RedlText.meta(color: RedlColors.accentTint),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: RedlColors.surface2, borderRadius: BorderRadius.circular(RedlRadius.sm)),
            child: const Icon(Icons.military_tech, size: 28, color: RedlColors.accent),
          ),
          const SizedBox(height: 6),
          Text(
            badge.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: RedlText.eyebrow(fontSize: 8, color: RedlColors.baseAlt),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: RedlText.body(color: RedlColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(AppLocalizations.of(context)!.actionRetry)),
        ],
      ),
    );
  }
}
