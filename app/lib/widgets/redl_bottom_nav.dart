import 'package:flutter/material.dart';

import '../theme/redl_colors.dart';
import '../theme/redl_spacing.dart';

class RedlBottomNav extends StatelessWidget {
  const RedlBottomNav({super.key, required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _icons = [Icons.home_rounded, Icons.fiber_manual_record, Icons.two_wheeler_rounded, Icons.person_rounded];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RedlColors.base,
      padding: const EdgeInsets.symmetric(horizontal: RedlSpacing.screenPadding, vertical: 14),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_icons.length, (index) {
            final active = index == currentIndex;
            return GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: active ? RedlColors.accent : RedlColors.surface4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(_icons[index], size: 14, color: RedlColors.baseAlt),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
