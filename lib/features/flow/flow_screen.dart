import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/database_event_bus.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/beat_log_repository.dart';
import 'package:rythem_app/core/pacing/pacing.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/utils/resource_launcher.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/ai/services/local_inference_service.dart';
import 'confusing_beat_dialog.dart';
import 'session_detail_screen.dart';
import '../explore/widgets/chapter_accordion.dart';
import '../../core/navigation/smooth_page_route.dart';

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
  final BeatLogRepository? beatLogRepo;
  final VoidCallback onSwitchRoadmap;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final VoidCallback? onExploreTracks;
  final void Function(RoadmapEntity roadmap)? onOpenRoadmapDetail;
  final LocalInferenceService? inferenceService;
  final Set<String> delayedBeatIds;
  final void Function(BeatEntity beat)? onToggleDelay;
  final Future<void> Function(RoadmapEntity roadmap)? onStartEarly;
  final Map<String, String> activeFocusBeatByRoadmap;
  final void Function(RoadmapEntity roadmap)? onPullNextTopic;
  final void Function(RoadmapEntity roadmap, BeatEntity beat)? onReturnToTracker;

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
    this.beatLogRepo,
    required this.onSwitchRoadmap,
    required this.onBeatToggled,
    this.onExploreTracks,
    this.onOpenRoadmapDetail,
    this.inferenceService,
    this.delayedBeatIds = const {},
    this.onToggleDelay,
    this.onStartEarly,
    this.activeFocusBeatByRoadmap = const {},
    this.onPullNextTopic,
    this.onReturnToTracker,
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

    // Filter roadmaps based on selection pill
    final displayedRoadmaps = _selectedTrackFilter == 'all'
        ? roadmaps
        : roadmaps.where((r) => r.id == _selectedTrackFilter).toList();

    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Active Track Switcher
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
            ],
          ),

          const SizedBox(height: 16),

          // Streak Calendar (7-day glass round cells + notification badges)
          _FlowStreakCalendar(
            streakDays: widget.streakDays,
            allBeats: widget.allBeats,
            beatLogRepo: widget.beatLogRepo,
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

              return _TrackTodoListCard(
                roadmap: rm,
                chapters: rmChapters,
                allBeats: rmBeats,
                pacingBudget: rmBudget,
                themeColors: themeColors,
                isDark: isDark,
                activeFocusBeatId: widget.activeFocusBeatByRoadmap[rm.id],
                onPullNextTopic: widget.onPullNextTopic != null ? () => widget.onPullNextTopic!(rm) : null,
                onReturnToTracker: widget.onReturnToTracker,
                delayedBeatIds: widget.delayedBeatIds,
                onToggleDelay: widget.onToggleDelay,
                onBeatToggled: widget.onBeatToggled,
                onOpenFocusSession: (beat) => _openFocusSession(context, rm, rmChapters, rmBeats, beat),
                onStartEarly: widget.onStartEarly,
                onOpenDetail: widget.onOpenRoadmapDetail != null
                    ? () => widget.onOpenRoadmapDetail!(rm)
                    : null,
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
      SmoothPageRoute(
        child: SessionDetailScreen(
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
  final PacingBudget? pacingBudget;
  final RythemColorTokens themeColors;
  final bool isDark;
  final String? activeFocusBeatId;
  final VoidCallback? onPullNextTopic;
  final void Function(RoadmapEntity roadmap, BeatEntity beat)? onReturnToTracker;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final void Function(BeatEntity beat) onOpenFocusSession;
  final VoidCallback? onOpenDetail;
  final Set<String> delayedBeatIds;
  final void Function(BeatEntity beat)? onToggleDelay;
  final Future<void> Function(RoadmapEntity roadmap)? onStartEarly;

  const _TrackTodoListCard({
    required this.roadmap,
    required this.chapters,
    required this.allBeats,
    required this.pacingBudget,
    required this.themeColors,
    required this.isDark,
    this.activeFocusBeatId,
    this.onPullNextTopic,
    this.onReturnToTracker,
    required this.onBeatToggled,
    required this.onOpenFocusSession,
    this.onOpenDetail,
    this.delayedBeatIds = const {},
    this.onToggleDelay,
    this.onStartEarly,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = allBeats.where((b) => b.isCompleted).length;
    final totalCount = allBeats.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) => Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, 8 * (1.0 - anim)),
          child: child,
        ),
      ),
      child: RepaintBoundary(
        child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.35)
                  : const Color(0xFF0E1420).withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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

                // Check if track is scheduled to start in the future
                final trackStart = roadmap.startDate != null
                    ? DateTime(roadmap.startDate!.year, roadmap.startDate!.month, roadmap.startDate!.day)
                    : todayStart;
                final isUpcoming = pacingBudget?.isUpcoming == true || todayStart.isBefore(trackStart);

                // Active beat candidate (user-driven pulled topic)
                BeatEntity? activeBeat;
                if (activeFocusBeatId != null) {
                  final candidate = sortedAllBeats.where((b) => b.id == activeFocusBeatId).firstOrNull;
                  if (candidate != null && !candidate.isCompleted) {
                    activeBeat = candidate;
                  }
                }

                if (isUpcoming && completedToday.isEmpty && activeBeat == null) {
                  final daysUntil = pacingBudget?.daysUntilStart ??
                      (todayStart.isBefore(trackStart) ? trackStart.difference(todayStart).inDays : 0);
                  return _buildUpcomingTrackCard(
                    context: context,
                    daysUntil: daysUntil,
                    startDate: roadmap.startDate ?? trackStart,
                  );
                }

                final hasIncompleteBeats = sortedAllBeats.any((b) => !b.isCompleted);
                final isAllTrackCompleted = allBeats.isNotEmpty && !hasIncompleteBeats;

                // Delayed beats that are not completed and not the active beat
                final delayedBeats = sortedAllBeats
                    .where((b) => !b.isCompleted && delayedBeatIds.contains(b.id) && b.id != activeBeat?.id)
                    .toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Active Focus Topic (if pulled)
                      if (activeBeat != null) ...[
                        () {
                          final currentBeat = activeBeat!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'CURRENT FOCUS',
                                      style: RythemTypography.labelSmall.copyWith(
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (onReturnToTracker != null)
                                      GestureDetector(
                                        onTap: () => onReturnToTracker!(roadmap, currentBeat),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.reply_rounded,
                                              size: 13,
                                              color: themeColors.textTertiary,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              'Return to Tracker',
                                              style: RythemTypography.labelSmall.copyWith(
                                                color: themeColors.textTertiary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              BeatTile(
                                beat: currentBeat,
                                themeColors: themeColors,
                                isDark: isDark,
                                isDelayed: delayedBeatIds.contains(currentBeat.id),
                                onToggleDelay: onToggleDelay != null ? () => onToggleDelay!(currentBeat) : null,
                                onToggle: (val) => onBeatToggled(currentBeat, val),
                                onOpenResource: () => ResourceLauncher.openResource(
                                  context,
                                  url: currentBeat.sourceUrl,
                                  title: currentBeat.title,
                                ),
                                onFlag: () {
                                  ConfusingBeatDialog.show(context, beat: currentBeat);
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        }(),
                      ],

                      // 2. Delayed Beats (if any exist)
                      if (delayedBeats.isNotEmpty) ...[
                        ...delayedBeats.map((beat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: BeatTile(
                                beat: beat,
                                themeColors: themeColors,
                                isDark: isDark,
                                isDelayed: true,
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
                              ),
                            )),
                      ],

                      // 3. Completed Today (celebratory checked items)
                      if (completedToday.isNotEmpty) ...[
                        if (activeBeat != null || delayedBeats.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6, left: 4),
                            child: Text(
                              'COMPLETED TODAY (${completedToday.length})',
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textTertiary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ...completedToday.map((beat) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: BeatTile(
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
                              ),
                            )),
                      ],

                      // 4. Empty State if nothing is pulled and nothing completed today
                      if (activeBeat == null && completedToday.isEmpty && delayedBeats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              isAllTrackCompleted
                                  ? 'All topics completed!'
                                  : 'No active topic in focus right now.',
                              style: RythemTypography.bodySmall.copyWith(
                                color: themeColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 6),

                      // 5. Pull Next Topic / Locked / All Completed Action Area
                      if (isAllTrackCompleted)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 15,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Track Complete! 100% Finished 🎉',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (activeBeat != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: themeColors.textTertiary.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Complete current topic to unlock next',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textTertiary.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (hasIncompleteBeats)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onPullNextTopic,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? themeColors.glassBorderHighlight : const Color(0x28000000),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: themeColors.textPrimary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pull Next Topic',
                                    style: RythemTypography.button.copyWith(
                                      color: themeColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // 6. View Full Tracker Footer Link
                      GestureDetector(
                        onTap: onOpenDetail,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Center(
                            child: Text(
                              'View full tracker (${allBeats.length} beats) →',
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    ),
  ),
),
),
),
    );
  }

  Widget _buildUpcomingTrackCard({
    required BuildContext context,
    required int daysUntil,
    required DateTime startDate,
  }) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final formattedDate = '${monthNames[startDate.month - 1]} ${startDate.day}, ${startDate.year}';
    final daysText = daysUntil == 1 ? 'Starts tomorrow' : 'Starts in $daysUntil days';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x1838BDF8) : const Color(0x100284C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x4038BDF8) : const Color(0x300284C7),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(isDark ? 0.3 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withOpacity(isDark ? 0.5 : 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Text(
                        'KICKOFF $formattedDate'.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    daysText,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Track Scheduled for $formattedDate',
              style: RythemTypography.titleMedium.copyWith(
                color: themeColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your curriculum and mentor queue are loaded and ready. Daily to-do recommendations will begin on kickoff day.',
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (onStartEarly != null)
                  GestureDetector(
                    onTap: () => onStartEarly!(roadmap),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Start Today Early',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                if (onOpenDetail != null)
                  GestureDetector(
                    onTap: onOpenDetail,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 14, color: themeColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Peek Syllabus',
                            style: TextStyle(
                              color: themeColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
    );
  }
}

/// Non-punitive recalibration notification banner when sustained shortfall occurs.


/// 7-day Ambient Glass Streak Calendar with horizontal week scrolling,
/// chevron navigation, and direct SQLite BeatLogRepository data pipeline.
class _FlowStreakCalendar extends StatefulWidget {
  final int streakDays;
  final List<BeatEntity> allBeats;
  final BeatLogRepository? beatLogRepo;
  final RythemColorTokens themeColors;
  final bool isDark;

  const _FlowStreakCalendar({
    required this.streakDays,
    required this.allBeats,
    this.beatLogRepo,
    required this.themeColors,
    required this.isDark,
  });

  @override
  State<_FlowStreakCalendar> createState() => _FlowStreakCalendarState();
}

class _FlowStreakCalendarState extends State<_FlowStreakCalendar> {
  int _weekOffset = 0; // 0 = current week, -1 = last week, etc.
  Map<String, int> _weekActivity = {};

  static const _emeraldAccent = Color(0xFF10B981);
  static const _weekDaysLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  StreamSubscription<DatabaseEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadWeekActivity();
    _eventSub = DatabaseEventBus.instance.stream.listen((_) {
      if (mounted) _loadWeekActivity();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_FlowStreakCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streakDays != widget.streakDays ||
        oldWidget.beatLogRepo != widget.beatLogRepo ||
        oldWidget.allBeats != widget.allBeats) {
      _loadWeekActivity();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  DateTime _getMondayForOffset(int offset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: offset * 7));
  }

  Future<void> _loadWeekActivity() async {
    final monday = _getMondayForOffset(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));
    final startStr = _formatDate(monday);
    final endStr = _formatDate(sunday);

    if (widget.beatLogRepo != null) {
      try {
        final activity = await widget.beatLogRepo!.getActivityForDateRange(startStr, endStr);
        if (mounted) {
          setState(() {
            _weekActivity = activity;
          });
        }
        return;
      } catch (_) {}
    }

    // Fallback if beatLogRepo is not provided
    final fallbackMap = <String, int>{};
    for (final b in widget.allBeats) {
      if (b.isCompleted && b.completedAt != null) {
        final dStr = _formatDate(b.completedAt!);
        if (dStr.compareTo(startStr) >= 0 && dStr.compareTo(endStr) <= 0) {
          fallbackMap[dStr] = (fallbackMap[dStr] ?? 0) + 1;
        }
      }
    }
    if (mounted) {
      setState(() {
        _weekActivity = fallbackMap;
      });
    }
  }

  void _previousWeek() {
    HapticFeedback.lightImpact();
    setState(() {
      _weekOffset--;
    });
    _loadWeekActivity();
  }

  void _nextWeek() {
    if (_weekOffset >= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _weekOffset++;
    });
    _loadWeekActivity();
  }

  void _resetToCurrentWeek() {
    if (_weekOffset == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _weekOffset = 0;
    });
    _loadWeekActivity();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = _getMondayForOffset(_weekOffset);
    final sunday = monday.add(const Duration(days: 6));

    final weekRangeTitle = _weekOffset == 0
        ? 'STREAK CALENDAR'
        : '${_monthAbbrs[monday.month - 1].toUpperCase()} ${monday.day} - ${_monthAbbrs[sunday.month - 1].toUpperCase()} ${sunday.day}';

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.isDark
                  ? Colors.black.withOpacity(0.30)
                  : const Color(0xFF0E1420).withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
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
                  color: widget.isDark ? widget.themeColors.glassBorder : const Color(0x18000000),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                weekRangeTitle,
                                overflow: TextOverflow.ellipsis,
                                style: RythemTypography.labelSmall.copyWith(
                                  color: widget.themeColors.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (_weekOffset < 0) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _resetToCurrentWeek,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: widget.themeColors.glassBorder,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Text(
                                    'TODAY',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: widget.themeColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: (widget.streakDays > 0 ? _emeraldAccent : widget.themeColors.textTertiary)
                                  .withOpacity(widget.isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: (widget.streakDays > 0 ? _emeraldAccent : widget.themeColors.textTertiary)
                                    .withOpacity(widget.isDark ? 0.4 : 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.streakDays > 0)
                                  const Text('🔥', style: TextStyle(fontSize: 10)),
                                if (widget.streakDays > 0)
                                  const SizedBox(width: 4),
                                Text(
                                  widget.streakDays > 0
                                      ? '${widget.streakDays} day${widget.streakDays == 1 ? '' : 's'} active'
                                      : '0 days active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: widget.streakDays > 0
                                        ? _emeraldAccent
                                        : widget.themeColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Left chevron
                          GestureDetector(
                            onTap: _previousWeek,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.chevron_left_rounded,
                                size: 16,
                                color: widget.themeColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Right chevron (disabled on current week)
                          GestureDetector(
                            onTap: _weekOffset < 0 ? _nextWeek : null,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: _weekOffset < 0
                                    ? widget.themeColors.textSecondary
                                    : widget.themeColors.textTertiary.withOpacity(0.25),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Swipeable Week Row
                  GestureDetector(
                    key: const Key('weekly_calendar_swipe_detector'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final vx = details.primaryVelocity ?? 0;
                      if (vx > 200) {
                        _previousWeek();
                      } else if (vx < -200 && _weekOffset < 0) {
                        _nextWeek();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (i) {
                        final dayDate = monday.add(Duration(days: i));
                        final dayStr = _formatDate(dayDate);
                        final isToday = dayDate.day == now.day &&
                            dayDate.month == now.month &&
                            dayDate.year == now.year;
                        final isPastOrToday = !dayDate.isAfter(DateTime(now.year, now.month, now.day));

                        final completedOnDay = _weekActivity[dayStr] ?? 0;
                        final isCompleted = completedOnDay > 0;

                        return Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _weekDaysLabels[i],
                                style: RythemTypography.labelSmall.copyWith(
                                  color: isToday ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
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
                                      color: isCompleted
                                          ? (widget.isDark ? _emeraldAccent.withOpacity(0.32) : Colors.teal.shade200)
                                          : (isToday
                                              ? (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
                                              : (widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03))),
                                      border: Border.all(
                                        color: isToday
                                            ? (widget.isDark ? Colors.white : Colors.black87)
                                            : (isCompleted
                                                ? (widget.isDark ? _emeraldAccent.withOpacity(0.65) : Colors.teal.shade500)
                                                : (widget.isDark ? widget.themeColors.glassBorder : const Color(0x10000000))),
                                        width: isToday ? 1.5 : (isCompleted ? 1.2 : 0.6),
                                      ),
                                      boxShadow: isCompleted
                                          ? [
                                              BoxShadow(
                                                color: _emeraldAccent.withOpacity(widget.isDark ? 0.25 : 0.15),
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
                                          color: isCompleted
                                              ? (widget.isDark ? Colors.white : Colors.teal.shade900)
                                              : (isToday
                                                  ? widget.themeColors.textPrimary
                                                  : (isPastOrToday ? widget.themeColors.textSecondary : widget.themeColors.textTertiary)),
                                          fontSize: 11,
                                          fontWeight: isCompleted || isToday ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (completedOnDay > 0)
                                    Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: widget.isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: widget.isDark ? const Color(0xFF181818) : Colors.white,
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
              'No Learning Tracks Yet',
              style: RythemTypography.titleMedium.copyWith(
                color: themeColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your flow queue is clear. Create or import your syllabus outline or link a playlist in Explore to begin.',
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (onExplore != null) ...[
              const SizedBox(height: 16),
              GlassButton(
                label: 'Create / Explore Tracks',
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
