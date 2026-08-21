import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_text_styles.dart';

const _prefsShownKey = 'redl_battery_prompt_shown';

/// Some OEMs (Samsung especially) aggressively kill apps running in the
/// background even with an active foreground service, which can cut a long
/// ride's GPS tracking short. Shown once, the first time a rider starts a
/// recording, if the app isn't already exempt from battery optimization.
Future<void> maybeShowBatteryOptimizationPrompt(BuildContext context) async {
  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) return;

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_prefsShownKey) ?? false) return;

  final status = await Permission.ignoreBatteryOptimizations.status;
  if (status.isGranted) return;

  await prefs.setBool(_prefsShownKey, true);
  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final shouldOpenSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: RedlColors.surface2,
      title: Text(l10n.batteryOptimizationTitle, style: RedlText.title(fontSize: 15)),
      content: Text(l10n.batteryOptimizationMessage, style: RedlText.body(fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.batteryOptimizationDismiss)),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text(l10n.batteryOptimizationAction)),
      ],
    ),
  );

  if (shouldOpenSettings == true) {
    await Permission.ignoreBatteryOptimizations.request();
  }
}
