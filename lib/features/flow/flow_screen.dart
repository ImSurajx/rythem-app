import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';
import 'confusing_beat_dialog.dart';
import 'session_detail_screen.dart';

/// Flow Screen (Home - opened most often) adhering to `docs/design.md` §2:
/// - Today's date & streak indicator
/// - Today's beat checklist: one row per pending beat across active roadmaps
/// - Evening unlock indicator (flips when daily mission quota is met)
/// - Single "flag something confusing" action
/// - Clean, glanceable - no clutter or complex charts
class FlowScreen extends StatelessWidget {
  final RoadmapEntity? activeRoadmap;
  final List<RoadmapEntity> allRoadmaps;
  final List<ChapterEntity> chapters;
  final List<BeatEntity> allBeats;
  final PacingBudget? pacingBudget;
  final int streakDays;
  final VoidCallback onSwitchRoadmap;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final VoidCallback? onExploreTracks;

  const FlowScreen({
    super.key,
    required this.activeRoadmap,
    required this.allRoadmaps,
    required this.chapters,
    required this.allBeats,
    required this.pacingBudget,
    required this.streakDays,
    required this.onSwitchRoadmap,
    required this.onBeatToggled,
    this.onExploreTracks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    final now = DateTime.now();
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER'
    ];
    final formattedDate =
        '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    // Determine today's mission beats from the pacing budget
    final todaysMissionBeats = pacingBudget?.todaysBeats ?? [];
    final hasMission = todaysMissionBeats.isNotEmpty;

    final completedMissionCount =
        todaysMissionBeats.where((b) => b.isCompleted).length;
    final totalMissionCount = todaysMissionBeats.length;
    final isEveningUnlocked =
        hasMission && completedMissionCount == totalMissionCount;

    final progressRatio = hasMission ? completedMissionCount / totalMissionCount : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Active Roadmap Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (allRoadmaps.length > 1)
                GestureDetector(
                  onTap: onSwitchRoadmap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? themeColors.glassBorder : const Color(0x14000000),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 14, color: themeColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Switch Track (${allRoadmaps.length})',
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: themeColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Streak
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeRoadmap?.title ?? 'Daily Flow',
                      style: RythemTypography.headlineMedium.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activeRoadmap != null
                          ? '${activeRoadmap!.status.toUpperCase()} • $totalMissionCount beats queued today'
                          : 'No active track',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Flow Streak Pill (Felt, not clock-measured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.offline_bolt_outlined,
                      size: 15,
                      color: themeColors.textPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Streak: $streakDays Day${streakDays == 1 ? '' : 's'}',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Evening Unlock Indicator (flips when daily mission quota is met)
          _EveningUnlockBanner(
            isUnlocked: isEveningUnlocked,
            completedCount: completedMissionCount,
            totalCount: totalMissionCount,
            progressRatio: progressRatio,
            themeColors: themeColors,
            isDark: isDark,
          ),

          const SizedBox(height: 24),

          // Section Header with Focus Mode Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S MISSION",
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              if (hasMission)
                GestureDetector(
                  onTap: () => _openFocusSession(context, todaysMissionBeats.first),
                  child: Row(
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        size: 16,
                        color: themeColors.textPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Start Focus Mode',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Today's Beat Checklist
          if (!hasMission)
            _EmptyMissionState(
              themeColors: themeColors,
              isDark: isDark,
              onExplore: onExploreTracks,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todaysMissionBeats.length,
              itemBuilder: (context, index) {
                final beat = todaysMissionBeats[index];
                final chapter = chapters.where((c) => c.id == beat.chapterId).firstOrNull;

                return _FlowBeatChecklistTile(
                  beat: beat,
                  chapterTitle: chapter?.title ?? 'Active Chapter',
                  themeColors: themeColors,
                  isDark: isDark,
                  onToggle: (val) => onBeatToggled(beat, val),
                  onTap: () => _openFocusSession(context, beat),
                  onFlag: () {
                    ConfusingBeatDialog.show(context, beat: beat);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _openFocusSession(BuildContext context, BeatEntity targetBeat) {
    HapticFeedback.lightImpact();
    final chapter = chapters.where((c) => c.id == targetBeat.chapterId).firstOrNull;
    final chapterBeats = allBeats.where((b) => b.chapterId == targetBeat.chapterId).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SessionDetailScreen(
          roadmapTitle: activeRoadmap?.title ?? 'Active Track',
          chapterTitle: chapter?.title ?? 'Current Chapter',
          beats: chapterBeats.isNotEmpty ? chapterBeats : [targetBeat],
          initialBeatId: targetBeat.id,
          onBeatToggled: onBeatToggled,
        ),
      ),
    );
  }
}

/// Evening Unlock Indicator Banner per `docs/design.md` §2:
/// - State A (In progress): shows remaining beats in mission
/// - State B (Unlocked): celebratory serene state when daily quota is met
class _EveningUnlockBanner extends StatelessWidget {
  final bool isUnlocked;
  final int completedCount;
  final int totalCount;
  final double progressRatio;
  final RythemColorTokens themeColors;
  final bool isDark;

  const _EveningUnlockBanner({
    required this.isUnlocked,
    required this.completedCount,
    required this.totalCount,
    required this.progressRatio,
    required this.themeColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (isUnlocked) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    Colors.white.withOpacity(0.14),
                    Colors.white.withOpacity(0.04),
                  ]
                : [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.02),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark ? themeColors.glassBorderHighlight : const Color(0x30000000),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08),
              ),
              child: Icon(
                Icons.nightlight_round,
                size: 22,
                color: themeColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVENING UNLOCKED',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Today\'s mission quota complete. Rest without guilt or catch up on sleep.',
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 16,
                    color: themeColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    totalCount == 0 ? 'MISSION CLEARED' : '$completedCount OF $totalCount BEATS DONE',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progressRatio * 100).toInt()}%',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlassProgressBar(
            progress: progressRatio,
            height: 6,
          ),
        ],
      ),
    );
  }
}

/// Single beat tile in today's checklist
class _FlowBeatChecklistTile extends StatelessWidget {
  final BeatEntity beat;
  final String chapterTitle;
  final RythemColorTokens themeColors;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onFlag;

  const _FlowBeatChecklistTile({
    required this.beat,
    required this.chapterTitle,
    required this.themeColors,
    required this.isDark,
    required this.onToggle,
    required this.onTap,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onToggle(!beat.isCompleted);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: beat.isCompleted
                        ? themeColors.textPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: beat.isCompleted
                          ? themeColors.textPrimary
                          : themeColors.textTertiary,
                      width: 1.5,
                    ),
                  ),
                  child: beat.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),

              // Title and Chapter Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beat.title,
                      style: RythemTypography.bodyMedium.copyWith(
                        color: beat.isCompleted
                            ? themeColors.textTertiary
                            : themeColors.textPrimary,
                        decoration:
                            beat.isCompleted ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          chapterTitle,
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${beat.effortWeight.toStringAsFixed(1)} effort',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Focus Arrow & Flag Button
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 16,
                  color: themeColors.textTertiary,
                ),
                onPressed: onFlag,
                tooltip: 'Flag Confusion',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: themeColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMissionState extends StatelessWidget {
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback? onExplore;

  const _EmptyMissionState({
    required this.themeColors,
    required this.isDark,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 36,
              color: themeColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'No Pending Beats Today',
              style: RythemTypography.titleMedium.copyWith(
                color: themeColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your queue is clear. Relax, review previous beats, or explore new tracks.',
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onExplore != null) ...[
              const SizedBox(height: 16),
              GlassButton(
                label: 'Explore Tracks',
                icon: Icons.explore_outlined,
                onPressed: onExplore!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
