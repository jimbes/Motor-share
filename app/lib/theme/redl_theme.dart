import 'package:flutter/material.dart';
import 'redl_colors.dart';
import 'redl_spacing.dart';

class RedlTheme {
  RedlTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: RedlColors.base,
      textTheme: base.textTheme.apply(fontFamily: 'Inter'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
      colorScheme: base.colorScheme.copyWith(
        surface: RedlColors.base,
        primary: RedlColors.accent,
        secondary: RedlColors.accent,
        error: RedlColors.accent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: RedlColors.base,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: RedlColors.baseAlt,
        ),
        iconTheme: IconThemeData(color: RedlColors.baseAlt),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RedlColors.accent,
          foregroundColor: RedlColors.baseAlt,
          disabledBackgroundColor: RedlColors.accent.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedlRadius.sm)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: RedlColors.baseAlt,
          side: const BorderSide(color: RedlColors.border, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedlRadius.sm)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RedlColors.baseAlt,
          textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RedlColors.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedlRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedlRadius.sm),
          borderSide: const BorderSide(color: RedlColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedlRadius.sm),
          borderSide: const BorderSide(color: RedlColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedlRadius.sm),
          borderSide: const BorderSide(color: RedlColors.accent, width: 1),
        ),
        labelStyle: const TextStyle(fontFamily: 'Inter', color: RedlColors.textSecondary),
        hintStyle: const TextStyle(fontFamily: 'Inter', color: RedlColors.textMuted),
      ),
      dividerTheme: const DividerThemeData(color: RedlColors.divider, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: RedlColors.surface3,
        contentTextStyle: const TextStyle(fontFamily: 'Inter', color: RedlColors.baseAlt),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RedlRadius.sm)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
