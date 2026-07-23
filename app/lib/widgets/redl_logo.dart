import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/redl_colors.dart';
import '../theme/redl_text_styles.dart';

/// The REDL apex-curve mark - an abstract monoline racing line, never a
/// literal wheel/helmet/vehicle illustration.
class RedlMark extends StatelessWidget {
  const RedlMark({super.key, this.size = 56, this.light = false});

  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final asset = light ? 'assets/images/redl-icon-white.svg' : 'assets/images/redl-icon-bordeaux.svg';
    return SvgPicture.asset(asset, width: size, height: size);
  }
}

/// Mark + "REDL" wordmark, stacked, as shown on the onboarding screen.
class RedlLockup extends StatelessWidget {
  const RedlLockup({super.key, this.markSize = 56, this.wordmarkSize = 22, this.showTagline = true});

  final double markSize;
  final double wordmarkSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RedlMark(size: markSize),
        const SizedBox(height: 16),
        Text(l10n.appName, style: RedlText.wordmark(fontSize: wordmarkSize)),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(l10n.appTagline, style: RedlText.body(fontSize: 15, color: RedlColors.textSecondary)),
        ],
      ],
    );
  }
}
