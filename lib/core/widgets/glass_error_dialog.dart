import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_button.dart';

/// A floating specular glass error window for displaying high-priority error feedback.
class GlassErrorDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onDismiss;
  final String dismissLabel;

  const GlassErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.retryLabel = 'Retry Download',
    this.onDismiss,
    this.dismissLabel = 'Dismiss',
  });

  /// Static helper to display the glass error dialog with smooth animation and blur backdrop.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
    VoidCallback? onDismiss,
    String dismissLabel = 'Dismiss',
  }) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Error Details',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return GlassErrorDialog(
          title: title,
          message: message,
          details: details,
          onRetry: onRetry,
          retryLabel: retryLabel,
          onDismiss: onDismiss,
          dismissLabel: dismissLabel,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: anim.value * 8.0,
            sigmaY: anim.value * 8.0,
          ),
          child: FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<GlassErrorDialog> createState() => _GlassErrorDialogState();
}

class _GlassErrorDialogState extends State<GlassErrorDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(300.0, 420.0),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.redAccent.withOpacity(0.35),
                      Colors.white.withOpacity(0.06),
                      Colors.redAccent.withOpacity(0.12),
                    ]
                  : [
                      Colors.white,
                      Colors.white.withOpacity(0.8),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.redAccent.withOpacity(isDark ? 0.18 : 0.08),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131318).withOpacity(0.88)
                      : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(isDark ? 0.12 : 0.4),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Glowing Error Badge Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.15),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.3),
                                blurRadius: 14,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: RythemTypography.titleMedium.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'System Diagnostic',
                                style: RythemTypography.caption.copyWith(
                                  color: Colors.redAccent.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error Message
                    Text(
                      widget.message,
                      style: RythemTypography.bodyMedium.copyWith(
                        color: themeColors.textSecondary,
                        height: 1.45,
                      ),
                    ),

                    // Expandable Technical Details
                    if (widget.details != null && widget.details!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showDetails = !_showDetails;
                          });
                        },
                        child: Row(
                          children: [
                            Text(
                              _showDetails ? 'Hide technical logs' : 'View technical logs',
                              style: RythemTypography.caption.copyWith(
                                color: themeColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showDetails
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: themeColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                      if (_showDetails) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(isDark ? 0.5 : 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Text(
                            widget.details!,
                            style: TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 11,
                              color: themeColors.textTertiary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 22),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: widget.dismissLabel,
                            variant: GlassButtonVariant.ghost,
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDismiss?.call();
                            },
                          ),
                        ),
                        if (widget.onRetry != null) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: GlassButton(
                              label: widget.retryLabel,
                              variant: GlassButtonVariant.primary,
                              icon: Icons.refresh_rounded,
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onRetry?.call();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
