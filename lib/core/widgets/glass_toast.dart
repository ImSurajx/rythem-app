import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Shows an ambient liquid glass notification toast replacing default opaque SnackBars.
void showGlassToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Color? accentColor,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  HapticFeedback.lightImpact();

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final themeColors = isDark ? RythemColors.dark : RythemColors.light;

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: EdgeInsets.zero,
      duration: duration,
      content: GlassToast(
        message: message,
        icon: icon,
        accentColor: accentColor,
        actionLabel: actionLabel,
        onAction: onAction,
        isDark: isDark,
        themeColors: themeColors,
      ),
    ),
  );
}

/// The visual liquid glass notification widget.
class GlassToast extends StatelessWidget {
  final String message;
  final IconData? icon;
  final Color? accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;
  final RythemColorTokens themeColors;

  const GlassToast({
    super.key,
    required this.message,
    this.icon,
    this.accentColor,
    this.actionLabel,
    this.onAction,
    required this.isDark,
    required this.themeColors,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? (isDark ? Colors.white : Colors.black);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xCC18191E)
                : const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : Colors.black.withOpacity(0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: effectiveAccent.withOpacity(isDark ? 0.15 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: effectiveAccent,
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: effectiveAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  message,
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: effectiveAccent.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: effectiveAccent.withOpacity(isDark ? 0.4 : 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: RythemTypography.labelSmall.copyWith(
                        color: effectiveAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
