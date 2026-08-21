import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/badge_info.dart';
import '../core/repositories/reward_repository.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';

/// The full badge catalog (REDL project doc, section 8.3.4): a 3-column
/// grid, earned badges in color, unearned ones greyed out.
class BadgeCatalogScreen extends StatefulWidget {
  const BadgeCatalogScreen({super.key});

  @override
  State<BadgeCatalogScreen> createState() => _BadgeCatalogScreenState();
}

class _BadgeCatalogScreenState extends State<BadgeCatalogScreen> {
  List<BadgeInfo>? _badges;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final badges = await context.read<RewardRepository>().catalog();
      if (mounted) setState(() => _badges = badges);
    } catch (_) {
      // Non-fatal - the screen just stays empty/retryable via pull-to-refresh.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDetail(BadgeInfo badge) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedlColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              RedlSpacing.screenPadding,
              20,
              RedlSpacing.screenPadding,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.military_tech,
                      color: badge.earned
                          ? RedlColors.accent
                          : RedlColors.textMuted,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: RedlText.title(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  badge.description,
                  style: RedlText.body(color: RedlColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  badge.earned && badge.earnedAt != null
                      ? l10n.badgeEarnedOnLabel(
                          '${badge.earnedAt!.day}/${badge.earnedAt!.month}/${badge.earnedAt!.year}',
                        )
                      : l10n.badgeNotEarnedStatus,
                  style: RedlText.meta(
                    color: badge.earned
                        ? RedlColors.accentTint
                        : RedlColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final badges = _badges ?? const [];
    final earnedCount = badges.where((b) => b.earned).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.badgeCatalogTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: RedlColors.accent),
              )
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
                    Text(
                      l10n.badgeProgressLabel(earnedCount, badges.length),
                      style: RedlText.eyebrow(),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badges.isEmpty ? 0 : earnedCount / badges.length,
                        minHeight: 6,
                        backgroundColor: RedlColors.surface3,
                        color: RedlColors.accent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: badges
                          .map(
                            (badge) => GestureDetector(
                              onTap: () => _showDetail(badge),
                              child: Column(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: RedlColors.surface2,
                                      borderRadius: BorderRadius.circular(
                                        RedlRadius.sm,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.military_tech,
                                      size: 28,
                                      color: badge.earned
                                          ? RedlColors.accent
                                          : RedlColors.textMuted.withValues(
                                              alpha: 0.4,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    badge.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: RedlText.eyebrow(
                                      fontSize: 8,
                                      color: badge.earned
                                          ? RedlColors.baseAlt
                                          : RedlColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
