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

/// Flow Screen (Home - opened most often) adhering to `docs/design.md` §2 & user flow:
/// - Today's date & streak indicator
/// - Shows the WHOLE todo list for each track at once (no waiting or step-by-step trickling)
/// - Highlights beats assigned to Today's Mission with specular glass badge
/// - Direct interactive checkboxes like a real todo app
/// - Evening unlock indicator (flips when daily mission quota is met)
/// - Tap any beat for distraction-free Focus Mode (Session Detail)
class FlowScreen extends StatefulWidget {
  final RoadmapEntity? activeRoadmap;
  final List<RoadmapEntity> allRoadmaps;
  final List<ChapterEntity> chapters;
  final List<BeatEntity> allBeats;
  final PacingBudget? pacingBudget;
  final Map<String, List<ChapterEntity>>? chaptersByRoadmap;
  final Map<String, List<BeatEntity>>? beatsByRoadmap;
  final Map<String, PacingBudget>? budgetsByRoadmap;
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
    this.chaptersByRoadmap,
    this.beatsByRoadmap,
    this.budgetsByRoadmap,
    required this.streakDays,
    required this.onSwitchRoadmap,
    required this.onBeatToggled,
    this.onExploreTracks,
  });

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  String _selectedTrackFilter = 'all';

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

    // Roadmaps to display
    final roadmaps = widget.allRoadmaps.isNotEmpty
        ? widget.allRoadmaps
        : (widget.activeRoadmap != null ? [widget.activeRoadmap!] : <RoadmapEntity>[]);

    // Compute mission totals across all tracks
    int totalMissionBeats = 0;
    int completedMissionBeats = 0;

    for (final rm in roadmaps) {
      final budget = widget.budgetsByRoadmap?[rm.id] ??
          (rm.id == widget.activeRoadmap?.id ? widget.pacingBudget : null);
      final mission = budget?.todaysBeats ?? [];
      totalMissionBeats += mission.length;
      completedMissionBeats += mission.where((b) => b.isCompleted).length;
    }

    final bool hasMission = totalMissionBeats > 0;
    final bool isEveningUnlocked =
        hasMission && completedMissionBeats == totalMissionBeats;
    final double missionProgressRatio =
        hasMission ? (completedMissionBeats / totalMissionBeats) : 0.0;

    // Filter roadmaps based on selection pill
    final displayedRoadmaps = _selectedTrackFilter == 'all'
        ? roadmaps
        : roadmaps.where((r) => r.id == _selectedTrackFilter).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Roadmap Selector
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
              if (roadmaps.length > 1)
                GestureDetector(
                  onTap: widget.onSwitchRoadmap,
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
                          'Tracks (${roadmaps.length})',
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
                      widget.activeRoadmap?.title ?? 'Daily Flow',
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
                      '${roadmaps.length} track${roadmaps.length == 1 ? '' : 's'} in progress • felt, not measured',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Flow Streak Pill (Zero clock counting)
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
                      'Streak: ${widget.streakDays} Day${widget.streakDays == 1 ? '' : 's'}',
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

          const SizedBox(height: 18),

          // Evening Unlock Indicator Banner
          _EveningUnlockBanner(
            isUnlocked: isEveningUnlocked,
            completedCount: completedMissionBeats,
            totalCount: totalMissionBeats,
            progressRatio: missionProgressRatio,
            themeColors: themeColors,
            isDark: isDark,
          ),

          const SizedBox(height: 18),

          // Multi-Track Filter Pill Bar (if multiple tracks exist)
          if (roadmaps.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTrackFilterPill(
                    id: 'all',
                    label: 'All Tracks (${roadmaps.length})',
                    isSelected: _selectedTrackFilter == 'all',
                    themeColors: themeColors,
                    isDark: isDark,
                  ),
                  ...roadmaps.map((rm) {
                    return _buildTrackFilterPill(
                      id: rm.id,
                      label: rm.title,
                      isSelected: _selectedTrackFilter == rm.id,
                      themeColors: themeColors,
                      isDark: isDark,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TODAY'S MISSION & TRACK TODO LISTS",
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Full Checklist',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Render Whole Todo List for Each Track
          if (displayedRoadmaps.isEmpty)
            _EmptyMissionState(
              themeColors: themeColors,
              isDark: isDark,
              onExplore: widget.onExploreTracks,
            )
          else
            ...displayedRoadmaps.map((rm) {
              final rmChapters = widget.chaptersByRoadmap?[rm.id] ??
                  (rm.id == widget.activeRoadmap?.id ? widget.chapters : <ChapterEntity>[]);
              final rmBeats = widget.beatsByRoadmap?[rm.id] ??
                  (rm.id == widget.activeRoadmap?.id ? widget.allBeats : <BeatEntity>[]);
              final rmBudget = widget.budgetsByRoadmap?[rm.id] ??
                  (rm.id == widget.activeRoadmap?.id ? widget.pacingBudget : null);

              final todaysBeats = rmBudget?.todaysBeats ?? [];
              final todaysBeatIds = todaysBeats.map((b) => b.id).toSet();

              return _TrackTodoListCard(
                roadmap: rm,
                chapters: rmChapters,
                allBeats: rmBeats,
                todaysBeatIds: todaysBeatIds,
                pacingBudget: rmBudget,
                themeColors: themeColors,
                isDark: isDark,
                onBeatToggled: widget.onBeatToggled,
                onOpenFocusSession: (beat) => _openFocusSession(context, rm, rmChapters, rmBeats, beat),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTrackFilterPill({
    required String id,
    required String label,
    required bool isSelected,
    required RythemColorTokens themeColors,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedTrackFilter = id);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.09))
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? themeColors.glassBorderHighlight : Colors.black87)
                : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: RythemTypography.labelSmall.copyWith(
            color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _openFocusSession(
    BuildContext context,
    RoadmapEntity roadmap,
    List<ChapterEntity> chapters,
    List<BeatEntity> beats,
    BeatEntity targetBeat,
  ) {
    HapticFeedback.lightImpact();
    final chapter = chapters.where((c) => c.id == targetBeat.chapterId).firstOrNull;
    final chapterBeats = beats.where((b) => b.chapterId == targetBeat.chapterId).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SessionDetailScreen(
          roadmapTitle: roadmap.title,
          chapterTitle: chapter?.title ?? 'Current Chapter',
          beats: chapterBeats.isNotEmpty ? chapterBeats : [targetBeat],
          initialBeatId: targetBeat.id,
          onBeatToggled: widget.onBeatToggled,
        ),
      ),
    );
  }
}

/// Renders the complete, unabridged todo list for a single track
class _TrackTodoListCard extends StatelessWidget {
  final RoadmapEntity roadmap;
  final List<ChapterEntity> chapters;
  final List<BeatEntity> allBeats;
  final Set<String> todaysBeatIds;
  final PacingBudget? pacingBudget;
  final RythemColorTokens themeColors;
  final bool isDark;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final void Function(BeatEntity beat) onOpenFocusSession;

  const _TrackTodoListCard({
    required this.roadmap,
    required this.chapters,
    required this.allBeats,
    required this.todaysBeatIds,
    required this.pacingBudget,
    required this.themeColors,
    required this.isDark,
    required this.onBeatToggled,
    required this.onOpenFocusSession,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = allBeats.where((b) => b.isCompleted).length;
    final totalCount = allBeats.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    // Group beats by chapter
    final chapterMap = {for (final c in chapters) c.id: c};

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x18FFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x14000000),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Track Header with title, progress, and focus launcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$completedCount/$totalCount Beats',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressRatio,
                          backgroundColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            themeColors.textPrimary.withOpacity(0.7),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(progressRatio * 100).toInt()}%',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? themeColors.glassBorder : const Color(0x10000000),
          ),

          // Whole Todo List of Beats
          if (allBeats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No beats in this track yet.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textTertiary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: allBeats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final beat = allBeats[index];
                final chapter = chapterMap[beat.chapterId];
                final isTodayMission = todaysBeatIds.contains(beat.id) && !beat.isCompleted;

                return _FlowBeatChecklistTile(
                  beat: beat,
                  chapterTitle: chapter?.title ?? 'Chapter ${beat.sortOrder + 1}',
                  isTodayMission: isTodayMission,
                  themeColors: themeColors,
                  isDark: isDark,
                  onToggle: (val) => onBeatToggled(beat, val),
                  onTap: () => onOpenFocusSession(beat),
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
}

/// Evening Unlock Indicator Banner per `docs/design.md` §2
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
                    totalCount == 0
                        ? 'MISSION CLEARED'
                        : '$completedCount OF $totalCount TODAY\'S MISSION BEATS DONE',
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

/// Single beat checklist tile in the whole todo list
class _FlowBeatChecklistTile extends StatelessWidget {
  final BeatEntity beat;
  final String chapterTitle;
  final bool isTodayMission;
  final RythemColorTokens themeColors;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback onFlag;

  const _FlowBeatChecklistTile({
    required this.beat,
    required this.chapterTitle,
    required this.isTodayMission,
    required this.themeColors,
    required this.isDark,
    required this.onToggle,
    required this.onTap,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isTodayMission
              ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.015)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTodayMission
                ? (isDark ? themeColors.glassBorderHighlight : Colors.black45)
                : (isDark ? themeColors.glassBorder : const Color(0x10000000)),
            width: isTodayMission ? 1.1 : 0.7,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Interactive Todo Checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(!beat.isCompleted);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: beat.isCompleted
                        ? themeColors.textPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: beat.isCompleted
                          ? themeColors.textPrimary
                          : (isTodayMission
                              ? themeColors.textPrimary
                              : themeColors.textTertiary),
                      width: 1.5,
                    ),
                  ),
                  child: beat.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 15,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Title and Chapter Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isTodayMission) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? themeColors.glassBorderHighlight : Colors.black26,
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            "TODAY'S MISSION",
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: themeColors.textPrimary,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          beat.title,
                          style: RythemTypography.bodyMedium.copyWith(
                            color: beat.isCompleted
                                ? themeColors.textTertiary
                                : themeColors.textPrimary,
                            decoration:
                                beat.isCompleted ? TextDecoration.lineThrough : null,
                            fontWeight: isTodayMission ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

            // Friction Action & Focus Indicator
            IconButton(
              icon: Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: themeColors.textTertiary,
              ),
              onPressed: onFlag,
              tooltip: 'Flag Confusion',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: themeColors.textTertiary,
            ),
          ],
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
              'No Targets Found in SQLite',
              style: RythemTypography.titleMedium.copyWith(
                color: themeColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your learning queue is clear. Explore curricula and ingest a YouTube track to get started.',
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
