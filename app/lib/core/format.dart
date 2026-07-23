import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

String formatDistanceKm(double km) => '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';

String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
  return '${seconds}s';
}

String formatSpeedKmh(double kmh) => '${kmh.toStringAsFixed(0)} km/h';

String formatRelativeDate(BuildContext context, DateTime dateTime) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  final local = dateTime.toLocal();
  final difference = now.difference(local);

  if (difference.inDays == 0 && now.day == local.day) return l10n.today;
  if (difference.inDays == 1 || (difference.inDays == 0 && now.day != local.day)) return l10n.yesterday;
  if (difference.inDays < 7) return l10n.daysAgo(difference.inDays);

  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(local);
}
