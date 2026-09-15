import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/utils/resource_launcher.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/ai/services/local_inference_service.dart';
import 'confusing_beat_dialog.dart';
import 'session_detail_screen.dart';
import 'widgets/backlog_decision_sheet.dart';
import 'widgets/daily_revision_board.dart';
import '../explore/widgets/chapter_accordion.dart';
import '../../core/revision/models/revision_item.dart';
import '../../core/widgets/glass_toast.dart';

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
  final void Function(RoadmapEntity roadmap)? onOpenRoadmapDetail;
  final Future<void> Function(RoadmapEntity roadmap, PacingDecision decision)? onApplyPacingDecision;
  final LocalInferenceService? inferenceService;
  final Set<String> delayedBeatIds;
  final void Function(BeatEntity beat)? onToggleDelay;

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
    this.onOpenRoadmapDetail,
    this.onApplyPacingDecision,
    this.inferenceService,
    this.delayedBeatIds = const {},
    this.onToggleDelay,
    this.revisionItems = const [],
    this.onMarkRevised,
    this.onFlagForRevision,
  });

  final List<RevisionItem> revisionItems;
  final ValueChanged<RevisionItem>? onMarkRevised;
  final ValueChanged<BeatEntity>? onFlagForRevision;

  @override
  State<FlowScreen> createState() => _FlowScreenState();
}

class _FlowScreenState extends State<FlowScreen> {
  String _selectedTrackFilter = 'all';
  bool _simulateLagState = false;

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

    // Filter roadmaps based on selection pill
    final displayedRoadmaps = _selectedTrackFilter == 'all'
        ? roadmaps
        : roadmaps.where((r) => r.id == _selectedTrackFilter).toList();

    // Check for sustained lag in any active roadmap
    RoadmapEntity? laggingRoadmap;
    PacingBudget? laggingBudget;
    for (final rm in roadmaps) {
      final budget = widget.budgetsByRoadmap?[rm.id] ??
          (rm.id == widget.activeRoadmap?.id ? widget.pacingBudget : null);
      if (budget != null &&
          budget.isSustainedLag &&
          !budget.isRoadmapCompleted &&
          budget.shortfallDebt > 0.5 &&
          budget.lagStreakDays >= 3) {
        laggingRoadmap = rm;
        laggingBudget = budget;
        break;
      }
    }

    // Support simulated lag state for immediate testing of Backlog Manager & AI Recalibration
    if (_simulateLagState && laggingRoadmap == null && roadmaps.isNotEmpty) {
      laggingRoadmap = roadmaps.first;
      laggingBudget = const PacingBudget(
        roadmapId: 'simulated_lag',
        todayEffortShare: 3.5,
        todaysSelectedEffort: 3.5,
        remainingEffort: 18.0,
        daysLeft: 10,
        todaysBeats: [],
        isSustainedLag: true,
        shortfallDebt: 4.5,
        lagStreakDays: 3,
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date, Tracks & Delay / Lag Simulator Tester
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  formattedDate,
                  overflow: TextOverflow.ellipsis,
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1-Click Lag / Backlog Simulator Test Pill
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _simulateLagState = !_simulateLagState;
                      });
                      if (_simulateLagState) {
                        showGlassToast(
                          context,
                          'Simulating Fall Behind lag. Backlog banner active.',
                          icon: Icons.warning_amber_rounded,
                          accentColor: Colors.amber,
                        );
                      } else {
                        showGlassToast(
                          context,
                          'Lag simulation cleared.',
                          icon: Icons.check_circle_outline_rounded,
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _simulateLagState
                            ? Colors.amber.withOpacity(isDark ? 0.22 : 0.15)
                            : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _simulateLagState
                              ? Colors.amber.withOpacity(isDark ? 0.5 : 0.4)
                              : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _simulateLagState ? Icons.bolt : Icons.tune_rounded,
                            size: 13,
                            color: _simulateLagState ? Colors.amber : themeColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _simulateLagState ? 'SIMULATING LAG' : 'TEST BACKLOG',
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: _simulateLagState ? Colors.amber : themeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (roadmaps.length > 1)
                    GestureDetector(
                      onTap: widget.onSwitchRoadmap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
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
                      '${roadmaps.length} active track${roadmaps.length == 1 ? '' : 's'}',
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
                      '${widget.streakDays} Day Streak',
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

          const SizedBox(height: 16),

          // Streak Calendar (7-day glass round cells + notification badges)
          _FlowStreakCalendar(
            streakDays: widget.streakDays,
            allBeats: widget.allBeats,
            themeColors: themeColors,
            isDark: isDark,
          ),

          // Sustained Lag Non-Punitive Recalibration Banner
          if (laggingRoadmap != null && laggingBudget != null) ...[
            const SizedBox(height: 16),
            _SustainedLagRecalibrationBanner(
              roadmap: laggingRoadmap,
              pacingBudget: laggingBudget,
              themeColors: themeColors,
              isDark: isDark,
              onRecalibrate: () {
                BacklogDecisionSheet.show(
                  context,
                  roadmap: laggingRoadmap!,
                  pacingBudget: laggingBudget!,
                  allRoadmaps: roadmaps,
                  inferenceService: widget.inferenceService,
                  onDecisionSelected: (decision) {
                    if (_simulateLagState) {
                      setState(() => _simulateLagState = false);
                      showGlassToast(
                        context,
                        'Pacing recalibrated! Backlog resolved.',
                        icon: Icons.auto_awesome_rounded,
                      );
                    }
                    widget.onApplyPacingDecision?.call(laggingRoadmap!, decision);
                  },
                );
              },
            ),
          ],

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
                "TODAY'S FOCUS",
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Queue',
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
                delayedBeatIds: widget.delayedBeatIds,
                onToggleDelay: widget.onToggleDelay,
                onBeatToggled: widget.onBeatToggled,
                onOpenFocusSession: (beat) => _openFocusSession(context, rm, rmChapters, rmBeats, beat),
                onOpenDetail: widget.onOpenRoadmapDetail != null
                    ? () => widget.onOpenRoadmapDetail!(rm)
                    : null,
              );
            }),

          const SizedBox(height: 16),
          // Moved Daily Revision Board below the todo lists as requested
          DailyRevisionBoard(
            revisionItems: widget.revisionItems,
            onMarkRevised: (item) => widget.onMarkRevised?.call(item),
            inferenceService: widget.inferenceService ?? LocalInferenceService(),
            themeColors: themeColors,
            isDark: isDark,
          ),
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
  final VoidCallback? onOpenDetail;
  final Set<String> delayedBeatIds;
  final void Function(BeatEntity beat)? onToggleDelay;

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
    this.onOpenDetail,
    this.delayedBeatIds = const {},
    this.onToggleDelay,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = allBeats.where((b) => b.isCompleted).length;
    final totalCount = allBeats.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : const Color(0xFF0E1420).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0x28FFFFFF),
                        const Color(0x14FFFFFF),
                        const Color(0x0AFFFFFF),
                      ]
                    : [
                        const Color(0x99FFFFFF),
                        const Color(0x66FFFFFF),
                        const Color(0x40FFFFFF),
                      ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Interactive Track Header with title, progress, and detail opener
          InkWell(
            onTap: onOpenDetail,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                            const SizedBox(width: 4),
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
        ),

          Divider(
            height: 1,
            color: isDark ? themeColors.glassBorder : const Color(0x10000000),
          ),

          // Actionable Focus Beats (Flow Focus)
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
          else ...[
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final completedToday = allBeats.where((b) {
                  if (!b.isCompleted) return false;
                  return b.completedAt != null && b.completedAt!.isAfter(todayStart);
                }).toList();

                // Sort beats strictly by chapter order first, then beat sort order
                final chapterOrderMap = <String, int>{};
                for (int c = 0; c < chapters.length; c++) {
                  chapterOrderMap[chapters[c].id] = chapters[c].sortOrder;
                }

                final sortedAllBeats = List<BeatEntity>.from(allBeats)
                  ..sort((a, b) {
                    final chA = chapterOrderMap[a.chapterId] ?? 999;
                    final chB = chapterOrderMap[b.chapterId] ?? 999;
                    if (chA != chB) return chA.compareTo(chB);
                    return a.sortOrder.compareTo(b.sortOrder);
                  });

                // Find active chapter with unfinished beats
                String? activeChapterId;
                for (final ch in chapters) {
                  final hasIncomplete = sortedAllBeats.any((b) => b.chapterId == ch.id && !b.isCompleted);
                  if (hasIncomplete) {
                    activeChapterId = ch.id;
                    break;
                  }
                }

                // Sequential queue from the active chapter first
                final pendingFromActive = sortedAllBeats
                    .where((b) => !b.isCompleted && (activeChapterId == null || b.chapterId == activeChapterId))
                    .take(3)
                    .toList();
                final remainingCount = 3 - pendingFromActive.length;
                final pendingNext = remainingCount > 0
                    ? sortedAllBeats
                        .where((b) => !b.isCompleted && b.chapterId != activeChapterId)
                        .take(remainingCount)
                        .toList()
                    : <BeatEntity>[];
                final pendingBeats = [...pendingFromActive, ...pendingNext];

                final seenIds = <String>{};
                final flowBeats = <BeatEntity>[];
                final delayedBeats = sortedAllBeats.where((b) => !b.isCompleted && delayedBeatIds.contains(b.id)).toList();
                for (final b in [...delayedBeats, ...completedToday, ...pendingBeats]) {
                  if (seenIds.add(b.id)) flowBeats.add(b);
                }
                if (flowBeats.isEmpty && sortedAllBeats.isNotEmpty) {
                  flowBeats.addAll(sortedAllBeats.take(3));
                }

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      itemCount: flowBeats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final beat = flowBeats[index];

                        return BeatTile(
                          beat: beat,
                          themeColors: themeColors,
                          isDark: isDark,
                          isDelayed: delayedBeatIds.contains(beat.id),
                          onToggleDelay: onToggleDelay != null ? () => onToggleDelay!(beat) : null,
                          onToggle: (val) => onBeatToggled(beat, val),
                          onOpenResource: () => ResourceLauncher.openResource(
                            context,
                            url: beat.sourceUrl,
                            title: beat.title,
                          ),
                          onFlag: () {
                            ConfusingBeatDialog.show(context, beat: beat);
                          },
                        );
                      },
                    ),
                    if (allBeats.length > flowBeats.length)
                      GestureDetector(
                        onTap: onOpenDetail,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                          child: Center(
                            child: Text(
                              'View full tracker (${allBeats.length} beats) →',
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    ),
  ),
),
    );
  }
}

/// Non-punitive recalibration notification banner when sustained shortfall occurs.
class _SustainedLagRecalibrationBanner extends StatelessWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final VoidCallback onRecalibrate;
  final RythemColorTokens themeColors;
  final bool isDark;

  const _SustainedLagRecalibrationBanner({
    required this.roadmap,
    required this.pacingBudget,
    required this.onRecalibrate,
    required this.themeColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onRecalibrate();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)).withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0x30F59E0B),
                          const Color(0x18F59E0B),
                        ]
                      : [
                          const Color(0x20F59E0B),
                          const Color(0x0CF59E0B),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0x60F59E0B) : const Color(0x40F59E0B),
                  width: 0.9,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 15,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "You're falling behind",
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'Review plan',
                        style: RythemTypography.labelSmall.copyWith(
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                      ),
                    ],
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

/// 7-day Ambient Glass Streak Calendar with circular cells and notification badges
class _FlowStreakCalendar extends StatelessWidget {
  final int streakDays;
  final List<BeatEntity> allBeats;
  final RythemColorTokens themeColors;
  final bool isDark;

  const _FlowStreakCalendar({
    required this.streakDays,
    required this.allBeats,
    required this.themeColors,
    required this.isDark,
  });

  static const _emeraldAccent = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Monday as start of week (weekday: Mon=1..Sun=7)
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    const weekDaysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.30)
                : const Color(0xFF0E1420).withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0x28FFFFFF),
                        const Color(0x14FFFFFF),
                        const Color(0x0AFFFFFF),
                      ]
                    : [
                        const Color(0x99FFFFFF),
                        const Color(0x66FFFFFF),
                        const Color(0x40FFFFFF),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'STREAK CALENDAR',
                  overflow: TextOverflow.ellipsis,
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _emeraldAccent.withOpacity(isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: _emeraldAccent.withOpacity(isDark ? 0.4 : 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 4),
                    Text(
                      '$streakDays day${streakDays == 1 ? '' : 's'} active',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _emeraldAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayDate = monday.add(Duration(days: i));
              final isToday = dayDate.day == now.day &&
                  dayDate.month == now.month &&
                  dayDate.year == now.year;
              final isPastOrToday = !dayDate.isAfter(DateTime(now.year, now.month, now.day));

              // Count beats completed on this day
              final completedOnDay = allBeats.where((b) {
                if (!b.isCompleted || b.completedAt == null) return false;
                final c = b.completedAt!;
                return c.year == dayDate.year && c.month == dayDate.month && c.day == dayDate.day;
              }).length;

              final daysDiff = DateTime(now.year, now.month, now.day)
                  .difference(DateTime(dayDate.year, dayDate.month, dayDate.day))
                  .inDays;
              final isWithinStreak = daysDiff >= 0 && daysDiff < streakDays;
              final isStreakMark = completedOnDay > 0 || isWithinStreak;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekDaysLabels[i],
                      style: RythemTypography.labelSmall.copyWith(
                        color: isToday ? themeColors.textPrimary : themeColors.textTertiary,
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? (isDark ? Colors.white : const Color(0xFF16181D))
                                : (isStreakMark
                                    ? (isDark ? _emeraldAccent.withOpacity(0.32) : Colors.teal.shade200)
                                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03))),
                            border: Border.all(
                              color: isToday
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : (isStreakMark
                                      ? (isDark ? _emeraldAccent.withOpacity(0.65) : Colors.teal.shade500)
                                      : (isDark ? themeColors.glassBorder : const Color(0x10000000))),
                              width: isToday ? 1.5 : (isStreakMark ? 1.2 : 0.6),
                            ),
                            boxShadow: isStreakMark
                                ? [
                                    BoxShadow(
                                      color: _emeraldAccent.withOpacity(isDark ? 0.25 : 0.15),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${dayDate.day}',
                              style: TextStyle(
                                color: isToday
                                    ? (isDark ? Colors.black : Colors.white)
                                    : (isStreakMark
                                        ? (isDark ? Colors.white : Colors.teal.shade900)
                                        : (isPastOrToday ? themeColors.textSecondary : themeColors.textTertiary)),
                                fontSize: 11,
                                fontWeight: isStreakMark || isToday ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        // Top-right notification dot badge with total beats
                        if (completedOnDay > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF181818) : Colors.white,
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$completedOnDay',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
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
