import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';

/// Persistent 4-item bottom dock adhering to `docs/design.md` §1:
/// - 4 icons only: Flow, Explore, Metrics, Settings with short labels
/// - Zero badges, zero notification counts
/// - Liquid glass frosted backdrop blur
class GlassBottomDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const GlassBottomDock({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  static const List<_DockItemData> _items = [
    _DockItemData(
      icon: Icons.waves_rounded,
      label: 'Flow',
    ),
    _DockItemData(
      icon: Icons.explore_outlined,
      label: 'Explore',
    ),
    _DockItemData(
      icon: Icons.insights_outlined,
      label: 'Metrics',
    ),
    _DockItemData(
      icon: Icons.settings_outlined,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = RythemColors.of(context);
    final effectiveBorderGradient = themeColors.specularBorderGradient;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.65) : const Color(0xFF0E1420).withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: effectiveBorderGradient,
      ),
      padding: const EdgeInsets.all(1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(33),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xB8121316) : const Color(0xCCFFFFFF),
              borderRadius: BorderRadius.circular(33),
            ),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final isSelected = selectedIndex == index;
                return Expanded(
                  child: _DockButton(
                    item: item,
                    isSelected: isSelected,
                    themeColors: themeColors,
                    isDark: isDark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onItemSelected(index);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItemData {
  final IconData icon;
  final String label;

  const _DockItemData({
    required this.icon,
    required this.label,
  });
}

class _DockButton extends StatelessWidget {
  final _DockItemData item;
  final bool isSelected;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onTap;

  const _DockButton({
    required this.item,
    required this.isSelected,
    required this.themeColors,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: isSelected
              ? Border.all(
                  color: isDark ? themeColors.glassBorderHighlight : const Color(0x20000000),
                  width: 1.0,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                size: 20,
                color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: RythemTypography.labelSmall.copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
