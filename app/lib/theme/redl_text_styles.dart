import 'package:flutter/material.dart';
import 'redl_colors.dart';

/// Inter throughout. No italics, no light weights.
class RedlText {
  RedlText._();

  static const _family = 'Inter';

  /// Wordmark / large headline - weight 800, wide positive tracking.
  static TextStyle wordmark({double fontSize = 22, Color color = RedlColors.baseAlt}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      letterSpacing: fontSize * 0.18,
      color: color,
    );
  }

  /// Section labels / eyebrows - weight 700, uppercase, small, tracked.
  static TextStyle eyebrow({double fontSize = 11, Color color = RedlColors.textMuted}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      letterSpacing: 1.4,
      color: color,
    );
  }

  /// Large numeral stat values - weight 800.
  static TextStyle statValue({double fontSize = 22, Color color = RedlColors.baseAlt}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      color: color,
    );
  }

  /// Titles / buttons - weight 700.
  static TextStyle title({double fontSize = 16, Color color = RedlColors.baseAlt}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color,
    );
  }

  /// Body copy - weight 400.
  static TextStyle body({double fontSize = 14, Color color = RedlColors.baseAlt}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w400,
      fontSize: fontSize,
      color: color,
    );
  }

  /// Secondary / meta copy - weight 400, muted.
  static TextStyle meta({double fontSize = 11, Color color = RedlColors.textMuted}) {
    return TextStyle(
      fontFamily: _family,
      fontWeight: FontWeight.w400,
      fontSize: fontSize,
      color: color,
    );
  }
}
