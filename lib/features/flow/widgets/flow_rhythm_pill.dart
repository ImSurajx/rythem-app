import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/models/roadmap_entity.dart';
import '../../../../core/pacing/models/pacing_budget.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Slim, non-intrusive Rhythm Pill HUD for FlowScreen.
/// Replaces the bulky 250px pace coach card with a 38px frosted capsule
/// that keeps today's tasks visible above the fold while offering 1-tap expansion.
class FlowRhythmPill extends StatelessWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onAdjust;
  final RythemColorTokens themeColors;
  final bool isDark;

  const FlowRhythmPill({
    super.key,
    required this.roadmap,
    required this.pacingBudget,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onAdjust,
    required this.themeColors,
    required this.isDark,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isBehind = pacingBudget.isBehindSchedule;
    final isOpenPace = pacingBudget.isOpenPace;

    final String statusLabel = isBehind
        ? 'Pace Adjusted'
        : isOpenPace
            ? 'Open Pace'
            : 'On Track';

    final IconData statusIcon = isBehind
        ? Icons.trending_up_rounded
        : isOpenPace
            ? Icons.all_inclusive_rounded
            : Icons.check_circle_outline_rounded;

    final velocity = pacingBudget.recentVelocity > 0
        ? pacingBudget.recentVelocity
        : pacingBudget.dailyEffortGuideline;

    final etaDate = pacingBudget.projectedCompletionDate ?? roadmap.targetCompletionDate;
    final etaStr = etaDate != null ? ' • ETA ${_formatDate(etaDate)}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onToggleExpand();
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    size: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: statusLabel,
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: ' • ${velocity.toStringAsFixed(1)}/day$etaStr',
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onAdjust();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Adjust',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: themeColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
