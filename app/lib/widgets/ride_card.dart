import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models/ride.dart';
import '../core/speed_color.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';
import '../theme/redl_text_styles.dart';
import 'route_preview_map.dart';

class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride, required this.onTap, required this.onToggleLike});

  final Ride ride;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: RedlColors.surface2,
          borderRadius: BorderRadius.circular(RedlRadius.sm),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 140, child: RoutePreviewMap(points: ride.routeLine, avgSpeedKmh: ride.avgSpeedKmh)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(ride.title, style: RedlText.title(fontSize: 13))),
                      if (ride.speedScore != null) ...[
                        const SizedBox(width: 8),
                        _ScoreBadge(score: ride.speedScore!, label: l10n.speedScoreLabel),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ride.user.name} · ${formatRelativeDate(context, ride.startedAt)}',
                    style: RedlText.meta(fontSize: 10.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Stat(label: l10n.statDistance, value: formatDistanceKm(ride.distanceKm)),
                      const SizedBox(width: 20),
                      _Stat(label: l10n.statDuration, value: formatDuration(ride.duration)),
                      const SizedBox(width: 20),
                      _Stat(label: l10n.statAvgSpeed, value: formatSpeedKmh(ride.avgSpeedKmh)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onToggleLike,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Icon(
                              ride.likedByMe ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: ride.likedByMe ? RedlColors.accent : RedlColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text('${ride.likesCount}', style: RedlText.meta(fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.chat_bubble_outline, size: 15, color: RedlColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${ride.commentsCount}', style: RedlText.meta(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score, required this.label});

  final int score;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = scoreToColor(score);
    return Tooltip(
      message: '$label: $score',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(RedlRadius.sm)),
        child: Text('$score', style: RedlText.title(fontSize: 12, color: color)),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: RedlText.eyebrow(fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: RedlText.body(fontSize: 12.5)),
      ],
    );
  }
}
