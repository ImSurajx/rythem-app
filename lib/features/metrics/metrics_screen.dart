import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/models/beat_entity.dart';
import '../../core/database/models/roadmap_entity.dart';
import '../../core/database/repositories/beat_log_repository.dart';
import '../../core/pacing/models/pacing_budget.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/glass_progress_bar.dart';

/// Production Metrics & Pacing Dashboard conforming to `docs/design.md` §5:
/// - Zero stopwatches or minute counting ("felt, not measured")
/// - Pure monochrome visual glass aesthetics
/// - Lifetime beat completion & effort weight totals
/// - 7-day activity bar chart with today highlighted
/// - Per-roadmap progress cards linking to detail screens
/// - Discreet pacing engine & simulation tools
class MetricsScreen extends StatelessWidget {
  final List<RoadmapEntity> roadmaps;
  final Map<String, List<BeatEntity>> beatsByRoadmap;
  final Map<String, PacingBudget>? budgetsByRoadmap;
  final PacingBudget? activeBudget;
  final int currentStreak;
  final List<DailyBeatCount> recentActivity;
  final DateTime? simulatedNow;
  final void Function(RoadmapEntity roadmap)? onOpenRoadmapDetail;
  final VoidCallback? onSimulateMissedDay;
  final VoidCallback? onCompleteTodaysQuota;
  final VoidCallback? onSimulate3DayLag;
  final VoidCallback? onResetSimulationClock;

  const MetricsScreen({
    super.key,
    required this.roadmaps,
    required this.beatsByRoadmap,
    this.budgetsByRoadmap,
    this.activeBudget,
    required this.currentStreak,
    required this.recentActivity,
    this.simulatedNow,
    this.onOpenRoadmapDetail,
    this.onSimulateMissedDay,
    this.onCompleteTodaysQuota,
    this.onSimulate3DayLag,
    this.onResetSimulationClock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    // Aggregate lifetime metrics across all roadmaps
    int totalBeats = 0;
    int completedBeats = 0;
    double totalEffort = 0.0;
    double completedEffort = 0.0;

    for (final beats in beatsByRoadmap.values) {
      for (final beat in beats) {
        totalBeats++;
        totalEffort += beat.effortWeight;
        if (beat.isCompleted) {
          completedBeats++;
          completedEffort += beat.effortWeight;
        }
      }
    }

    // Velocity from active budget or recent activity
    final double recentVelocity = activeBudget?.recentVelocity ??
        (recentActivity.isNotEmpty
            ? recentActivity.map((e) => e.count).reduce((a, b) => a + b) / 7.0
            : 0.0);

    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Sub-header
          Text(
            'METRICS',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),

          // Title & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Activity & Momentum',
                style: RythemTypography.headlineMedium.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (simulatedNow != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? themeColors.glassBorderHighlight : const Color(0x20000000),
                    ),
                  ),
                  child: Text(
                    'SIMULATED',
                    style: RythemTypography.labelSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: themeColors.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Felt, not measured • Zero stopwatches',
            style: RythemTypography.bodySmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 11.5,
            ),
          ),

          const SizedBox(height: 18),

          // Primary Metric Hero: Completed Beats
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COMPLETED BEATS',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$completedBeats of $totalBeats total',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$completedBeats',
                  style: RythemTypography.displayMedium.copyWith(
                    color: themeColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                ),
                const SizedBox(height: 14),
                // Supporting Metrics Row: Streak · Effort · Velocity
                Row(
                  children: [
                    _buildSupportingStat('Streak', '$currentStreak d', themeColors),
                    _buildStatDivider(themeColors),
                    _buildSupportingStat('Effort', '${completedEffort.toStringAsFixed(1)} / ${totalEffort.toStringAsFixed(1)}', themeColors),
                    _buildStatDivider(themeColors),
                    _buildSupportingStat('Velocity', '${recentVelocity.toStringAsFixed(1)} /d', themeColors),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 7-Day Monochrome Activity Bar Chart
          _SevenDayActivityChart(
            activity: recentActivity,
            themeColors: themeColors,
            isDark: isDark,
          ),

          const SizedBox(height: 22),

          // Active Tracks Overview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE TRACKS (${roadmaps.length})',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (roadmaps.isEmpty)
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No tracks currently active. Ingest or seed a roadmap to see live progress.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...roadmaps.map((rm) {
              final beats = beatsByRoadmap[rm.id] ?? [];
              final rmCompleted = beats.where((b) => b.isCompleted).length;
              final budget = budgetsByRoadmap?[rm.id] ??
                  (rm.id == activeBudget?.roadmapId ? activeBudget : null);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TrackOverviewCard(
                  roadmap: rm,
                  totalBeats: beats.length,
                  completedBeats: rmCompleted,
                  budget: budget,
                  themeColors: themeColors,
                  isDark: isDark,
                  onTap: () => onOpenRoadmapDetail?.call(rm),
                ),
              );
            }),

          const SizedBox(height: 14),

          // Pacing Engine Math & Simulation Box
          _PacingSimulatorExpander(
            activeBudget: activeBudget,
            simulatedNow: simulatedNow,
            themeColors: themeColors,
            isDark: isDark,
            onSimulateMissedDay: onSimulateMissedDay,
            onCompleteTodaysQuota: onCompleteTodaysQuota,
            onSimulate3DayLag: onSimulate3DayLag,
            onResetSimulationClock: onResetSimulationClock,
          ),
        ],
      ),
    );
  }
  Widget _buildSupportingStat(
    String label,
    String value,
    RythemThemeColors themeColors,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: RythemTypography.titleSmall.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(RythemThemeColors themeColors) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: themeColors.rowBorder,
    );
  }
}

class _SevenDayActivityChart extends StatelessWidget {
  final List<DailyBeatCount> activity;
  final RythemColorTokens themeColors;
  final bool isDark;

  const _SevenDayActivityChart({
    required this.activity,
    required this.themeColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Determine max count for scaling (minimum 4 to avoid huge bars on 1 completion)
    int maxCount = 4;
    for (final day in activity) {
      if (day.count > maxCount) maxCount = day.count;
    }

    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16, color: themeColors.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    '7-DAY ACTIVITY',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Text(
                'COMPLETED BEATS',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar Chart Container
          SizedBox(
            height: 125,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: activity.map((day) {
                final isToday = day.date == todayStr;
                final ratio = (day.count / maxCount).clamp(0.0, 1.0);
                final barHeight = (ratio * 65).clamp(day.count > 0 ? 10.0 : 4.0, 65.0);

                // Weekday abbreviation
                DateTime? parsed;
                try {
                  parsed = DateTime.parse(day.date);
                } catch (_) {}
                const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final dayLabel = parsed != null ? weekDays[parsed.weekday - 1] : '?';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Count label
                        Text(
                          day.count > 0 ? '${day.count}' : '',
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isToday ? themeColors.textPrimary : themeColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Visual Bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: barHeight,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isToday
                                ? (isDark ? Colors.white : Colors.black)
                                : (day.count > 0
                                    ? (isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35))
                                    : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))),
                            border: isToday
                                ? Border.all(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                    width: 1.2,
                                  )
                                : null,
                            boxShadow: isToday && day.count > 0
                                ? [
                                    BoxShadow(
                                      color: isDark ? Colors.white24 : Colors.black12,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Day name
                        Text(
                          dayLabel,
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday ? themeColors.textPrimary : themeColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackOverviewCard extends StatelessWidget {
  final RoadmapEntity roadmap;
  final int totalBeats;
  final int completedBeats;
  final PacingBudget? budget;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback? onTap;

  const _TrackOverviewCard({
    required this.roadmap,
    required this.totalBeats,
    required this.completedBeats,
    required this.budget,
    required this.themeColors,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = totalBeats > 0 ? (completedBeats / totalBeats) : 0.0;
    final bool isCompleted = totalBeats > 0 && completedBeats == totalBeats;

    String pacingStatus = 'ON TRACK';
    Color statusColor = const Color(0xFF34C759);

    if (isCompleted) {
      pacingStatus = 'COMPLETED';
      statusColor = const Color(0xFF34C759);
    } else if (budget?.isSustainedLag == true) {
      pacingStatus = 'LAGGING (${budget!.lagStreakDays}D)';
      statusColor = const Color(0xFFFF9500);
    } else if (budget?.isDailyQuotaCompleted == true) {
      pacingStatus = 'MISSION DONE';
      statusColor = const Color(0xFF34C759);
    }

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          roadmap.title,
                          style: RythemTypography.titleMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: themeColors.textTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    pacingStatus,
                    style: RythemTypography.labelSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassProgressBar(progress: progress),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedBeats / $totalBeats Beats (${(progress * 100).toInt()}%)',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                if (budget != null)
                  Text(
                    '${budget!.daysLeft} days left',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
  }
}

class _PacingSimulatorExpander extends StatefulWidget {
  final PacingBudget? activeBudget;
  final DateTime? simulatedNow;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback? onSimulateMissedDay;
  final VoidCallback? onCompleteTodaysQuota;
  final VoidCallback? onSimulate3DayLag;
  final VoidCallback? onResetSimulationClock;

  const _PacingSimulatorExpander({
    required this.activeBudget,
    required this.simulatedNow,
    required this.themeColors,
    required this.isDark,
    this.onSimulateMissedDay,
    this.onCompleteTodaysQuota,
    this.onSimulate3DayLag,
    this.onResetSimulationClock,
  });

  @override
  State<_PacingSimulatorExpander> createState() => _PacingSimulatorExpanderState();
}

class _PacingSimulatorExpanderState extends State<_PacingSimulatorExpander> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_outlined,
                      size: 16,
                      color: widget.themeColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PACING SIMULATOR & ENGINE',
                      style: RythemTypography.labelSmall.copyWith(
                        color: widget.themeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: widget.themeColors.textTertiary,
                ),
              ],
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            // Current Pacing Snapshot
            Row(
              children: [
                Expanded(
                  child: _simulatorMetricTile(
                    title: "TODAY'S BUDGET",
                    value: '${widget.activeBudget?.formattedBudget ?? "0.0"} effort',
                    subtitle: 'remaining ÷ days',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _simulatorMetricTile(
                    title: 'DAYS LEFT',
                    value: '${widget.activeBudget?.daysLeft ?? 0} days',
                    subtitle: 'calendar window',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _simulatorMetricTile(
                    title: 'PENDING EFFORT',
                    value: widget.activeBudget?.remainingEffort.toStringAsFixed(1) ?? '0.0',
                    subtitle: 'uncompleted sum',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'TEST PRESET ACTIONS',
              style: RythemTypography.labelSmall.copyWith(
                color: widget.themeColors.textTertiary,
                fontSize: 9.5,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onSimulateMissedDay != null)
                  _simulatorChip(
                    label: '+1 Missed Day (Dilution)',
                    onTap: widget.onSimulateMissedDay!,
                  ),
                if (widget.onCompleteTodaysQuota != null)
                  _simulatorChip(
                    label: "Complete Today's Mission",
                    onTap: widget.onCompleteTodaysQuota!,
                  ),
                if (widget.onSimulate3DayLag != null)
                  _simulatorChip(
                    label: 'Simulate 3-Day Lag (Adaptation)',
                    onTap: widget.onSimulate3DayLag!,
                  ),
                if (widget.simulatedNow != null && widget.onResetSimulationClock != null)
                  _simulatorChip(
                    label: 'Reset Clock',
                    onTap: widget.onResetSimulationClock!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _simulatorMetricTile({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isDark ? widget.themeColors.glassBorder : const Color(0x14000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: RythemTypography.labelSmall.copyWith(
              color: widget.themeColors.textTertiary,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: RythemTypography.titleMedium.copyWith(
              color: widget.themeColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: RythemTypography.bodySmall.copyWith(
              color: widget.themeColors.textTertiary,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _simulatorChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isDark ? widget.themeColors.glassBorder : const Color(0x18000000),
          ),
        ),
        child: Text(
          label,
          style: RythemTypography.labelSmall.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.themeColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
