import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/models/roadmap_entity.dart';
import '../../../../core/pacing/models/pacing_budget.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Intelligent Pace Coach Card (GPS ETA style, zero backlog debt).
/// Displays non-punitive pace health, projected completion date,
/// daily effort guidelines, and 1-tap timeline extension.
class PaceCoachCard extends StatelessWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onOpenTimelineAdjuster;
  final VoidCallback onQuickExtendSevenDays;

  const PaceCoachCard({
    super.key,
    required this.roadmap,
    required this.pacingBudget,
    required this.themeColors,
    required this.isDark,
    required this.onOpenTimelineAdjuster,
    required this.onQuickExtendSevenDays,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'No Deadline';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isBehind = pacingBudget.isBehindSchedule;
    final isOpenPace = pacingBudget.isOpenPace;
    final targetDate = roadmap.targetCompletionDate;
    final projectedDate = pacingBudget.projectedCompletionDate;

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

    // User-driven progress guideline message
    final String userDrivenMessage = isOpenPace
        ? 'Self-paced rhythm (~${pacingBudget.recentVelocity.toStringAsFixed(1)} lessons/active day).'
        : isBehind
            ? 'Your momentum is ${pacingBudget.recentVelocity.toStringAsFixed(1)} lessons/day. Tap Adjust Pace or +7 Days anytime to match your flow.'
            : pacingBudget.guidelineMessage.isNotEmpty
                ? pacingBudget.guidelineMessage
                : 'Great momentum! Target is well within your current learning rhythm.';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131724) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : const Color(0xFF0E1420).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Pace Coach title & Status Pill (Monochrome Glass)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0x28FFFFFF) : const Color(0x14000000),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.speed_rounded,
                            size: 16,
                            color: themeColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PACE COACH',
                          style: RythemTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    // Status Pill (Monochrome Frosted Glass)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: themeColors.textPrimary),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: themeColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ETA vs Target Information Grid (Monochrome)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Target Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target Date',
                              style: RythemTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: themeColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(targetDate),
                              style: RythemTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: themeColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      const SizedBox(width: 14),
                      // Projected Finish
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Projected ETA',
                              style: RythemTypography.labelSmall.copyWith(
                                fontSize: 11,
                                color: themeColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(projectedDate),
                              style: RythemTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: themeColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Guideline Message (User-driven progress, encouraging)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: themeColors.textSecondary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        userDrivenMessage,
                        style: RythemTypography.bodySmall.copyWith(
                          fontSize: 12,
                          color: themeColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Action Buttons: 1-Tap "+7 Days" and "Adjust" (Strictly Monochrome Glass)
                Row(
                  children: [
                    // Quick +7 Days Button
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onQuickExtendSevenDays();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.02),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_rounded, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '+7 Days',
                              style: RythemTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: themeColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Adjust Timeline Button (Monochrome Glass)
                    Expanded(
                      flex: 5,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onOpenTimelineAdjuster();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          elevation: 0,
                          backgroundColor: isDark
                              ? const Color(0x18FFFFFF)
                              : const Color(0x0C000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0x28FFFFFF)
                                  : const Color(0x18000000),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_calendar_rounded, size: 14, color: themeColors.textPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Adjust Pace',
                              style: RythemTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: themeColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
