import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/updater/updater.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_card.dart';

class SoftwareUpdateCard extends StatelessWidget {
  final UpdateReleaseInfo? latestRelease;
  final bool isChecking;
  final VoidCallback onCheckForUpdates;
  final VoidCallback? onOpenUpdateModal;

  const SoftwareUpdateCard({
    super.key,
    this.latestRelease,
    this.isChecking = false,
    required this.onCheckForUpdates,
    this.onOpenUpdateModal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = isDark ? RythemColors.dark : RythemColors.light;

    final hasUpdate = latestRelease?.isUpdateAvailable ?? false;
    const warningColor = Color(0xFFF59E0B);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Software Update',
                    style: RythemTypography.titleSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (hasUpdate) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: warningColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: warningColor.withOpacity(0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'NEW',
                        style: RythemTypography.labelSmall.copyWith(
                          color: warningColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Icon(
                hasUpdate
                    ? Icons.system_update_rounded
                    : Icons.check_circle_outline_rounded,
                size: 16,
                color: hasUpdate ? warningColor : colors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasUpdate
                ? 'A new version (${latestRelease!.tagName}) is available with the latest features and fixes.'
                : 'Rythem v${GithubReleaseService.currentAppVersion} • Running the latest release from GitHub.',
            style: RythemTypography.bodySmall.copyWith(
              color: colors.textTertiary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: isChecking
                      ? null
                      : (hasUpdate && onOpenUpdateModal != null
                          ? onOpenUpdateModal!
                          : onCheckForUpdates),
                  icon: isChecking
                      ? Icons.hourglass_top_rounded
                      : (hasUpdate
                          ? Icons.arrow_circle_up_rounded
                          : Icons.refresh_rounded),
                  label: isChecking
                      ? 'Checking...'
                      : (hasUpdate ? 'View Update (${latestRelease!.tagName})' : 'Check for Updates'),
                  variant: hasUpdate
                      ? GlassButtonVariant.primary
                      : GlassButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
