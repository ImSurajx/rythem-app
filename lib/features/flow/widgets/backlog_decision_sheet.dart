import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/models/roadmap_entity.dart';
import '../../../../core/pacing/models/pacing_budget.dart';
import '../../../../core/pacing/models/pacing_decision.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Non-punitive backlog adaptation sheet per `docs/design.md` §3.
/// Presents 4 guilt-free recalibration options when sustained lag is detected.
class BacklogDecisionSheet extends StatelessWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final List<RoadmapEntity> allRoadmaps;
  final ValueChanged<PacingDecision> onDecisionSelected;

  const BacklogDecisionSheet({
    super.key,
    required this.roadmap,
    required this.pacingBudget,
    this.allRoadmaps = const [],
    required this.onDecisionSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required RoadmapEntity roadmap,
    required PacingBudget pacingBudget,
    List<RoadmapEntity> allRoadmaps = const [],
    required ValueChanged<PacingDecision> onDecisionSelected,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BacklogDecisionSheet(
        roadmap: roadmap,
        pacingBudget: pacingBudget,
        allRoadmaps: allRoadmaps,
        onDecisionSelected: (decision) {
          Navigator.of(ctx).pop();
          onDecisionSelected(decision);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    final otherRoadmaps = allRoadmaps.where((r) => r.id != roadmap.id).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14171A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: themeColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'BACKLOG RECALIBRATION',
                        style: RythemTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: themeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${pacingBudget.lagStreakDays}d lag trend',
                      style: RythemTypography.labelSmall.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: themeColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Life happens. Rythem recalculates your path without penalty, guilt, or broken streaks.',
                style: RythemTypography.bodySmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),

              // Option 1: Extend Target Date
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.update_rounded,
                title: 'Push Target Date (+7 Days)',
                subtitle: 'Gently dilutes remaining effort across 7 extra calendar days to ease your daily load.',
                badge: 'RECOMMENDED',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onDecisionSelected(const PacingDecision.extendDate(7));
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Trim to Core Beats
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.filter_alt_outlined,
                title: 'Trim to Core Must-Do Beats',
                subtitle: 'Temporarily deprioritizes optional mentor extras, keeping you locked onto primary milestones.',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onDecisionSelected(const PacingDecision.trimCore());
                },
              ),
              const SizedBox(height: 12),

              // Option 3: Borrow Pace (if multiple tracks)
              if (otherRoadmaps.isNotEmpty) ...[
                _buildOptionCard(
                  context: context,
                  themeColors: themeColors,
                  isDark: isDark,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Borrow Pace from "${otherRoadmaps.first.title}"',
                  subtitle: 'Redistributes effort share across tracks to protect momentum on this roadmap.',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onDecisionSelected(PacingDecision.borrow(otherRoadmaps.first.id));
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Option 4: Accept & Continue
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.check_circle_outline_rounded,
                title: 'Accept & Keep Pace',
                subtitle: 'Dismiss this reminder. Your daily streak and current schedule remain completely intact.',
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDecisionSelected(const PacingDecision.accept());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required RythemThemeColors themeColors,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: themeColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: RythemTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
