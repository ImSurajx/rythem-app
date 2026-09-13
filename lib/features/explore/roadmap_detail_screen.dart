import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';
import 'package:rythem_app/features/flow/confusing_beat_dialog.dart';
import 'package:rythem_app/features/flow/session_detail_screen.dart';
import 'widgets/chapter_accordion.dart';

/// Roadmap Detail Screen per `docs/design.md` §5:
/// - Opened from Explore or Metrics
/// - Header: Roadmap title, category, progress bar, beat-ratio ("7 of 21")
/// - Single "Attach Resource" action
/// - Accordion list of chapters (first chapter open by default)
/// - Beats with checkboxes inside each chapter
/// - `mentor extra` badge on unaligned beats
/// - Zero video players, zero long syllabus text
/// - One-tap archive with immediate one-tap undo banner (no blocking popups)
class RoadmapDetailScreen extends StatefulWidget {
  final RoadmapEntity roadmap;
  final List<ChapterEntity> chapters;
  final List<BeatEntity> beats;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final Future<void> Function(RoadmapEntity roadmap)? onArchiveRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onRestoreRoadmap;
  final Future<void> Function(String roadmapId, String resourceUrl)? onAttachResource;

  const RoadmapDetailScreen({
    super.key,
    required this.roadmap,
    required this.chapters,
    required this.beats,
    required this.onBeatToggled,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onAttachResource,
  });

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late RoadmapEntity _currentRoadmap;
  late List<BeatEntity> _currentBeats;

  @override
  void initState() {
    super.initState();
    _currentRoadmap = widget.roadmap;
    _currentBeats = List.from(widget.beats);
  }

  @override
  void didUpdateWidget(RoadmapDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roadmap != widget.roadmap) {
      _currentRoadmap = widget.roadmap;
    }
    if (oldWidget.beats != widget.beats) {
      _currentBeats = List.from(widget.beats);
    }
  }

  Future<void> _handleBeatToggle(BeatEntity beat, bool isCompleted) async {
    final updated = beat.copyWith(isCompleted: isCompleted);
    setState(() {
      final index = _currentBeats.indexWhere((b) => b.id == beat.id);
      if (index != -1) {
        _currentBeats[index] = updated;
      }
    });
    await widget.onBeatToggled(beat, isCompleted);
  }

  void _handleArchive() {
    HapticFeedback.mediumImpact();
    final archivedRoadmap = _currentRoadmap;
    widget.onArchiveRoadmap?.call(archivedRoadmap);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Track "${archivedRoadmap.title}" archived',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xE6202020),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onRestoreRoadmap?.call(archivedRoadmap);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );

    Navigator.of(context).pop();
  }

  void _showAttachResourceDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final themeColors = isDark ? RythemColors.dark : RythemColors.light;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xF0181818) : const Color(0xF5FFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? themeColors.glassBorder : const Color(0x20000000),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ATTACH RESOURCE',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: themeColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Link a YouTube playlist, crash course video, or documentation link to ingest and align into beats.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  style: TextStyle(color: themeColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/playlist?list=... or video URL',
                    hintStyle: TextStyle(color: themeColors.textTertiary, fontSize: 12),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: themeColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: themeColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? themeColors.glassBorderHighlight : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: 'Attach & Ingest',
                    icon: Icons.link_rounded,
                    onPressed: () {
                      final url = controller.text.trim();
                      if (url.isNotEmpty) {
                        Navigator.pop(ctx);
                        widget.onAttachResource?.call(_currentRoadmap.id, url);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Attached resource: $url'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openFocusSession(BeatEntity targetBeat) {
    HapticFeedback.lightImpact();
    final chapter = widget.chapters.where((c) => c.id == targetBeat.chapterId).firstOrNull;
    final chapterBeats = _currentBeats.where((b) => b.chapterId == targetBeat.chapterId).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SessionDetailScreen(
          roadmapTitle: _currentRoadmap.title,
          chapterTitle: chapter?.title ?? 'Active Chapter',
          beats: chapterBeats.isNotEmpty ? chapterBeats : [targetBeat],
          initialBeatId: targetBeat.id,
          onBeatToggled: _handleBeatToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    final completedCount = _currentBeats.where((b) => b.isCompleted).length;
    final totalCount = _currentBeats.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final category = _currentRoadmap.description?.isNotEmpty == true
        ? _currentRoadmap.description!
        : 'CURRICULUM TRACK';

    // Group beats by chapter
    final chapterBeatsMap = <String, List<BeatEntity>>{};
    for (final ch in widget.chapters) {
      chapterBeatsMap[ch.id] = [];
    }
    for (final b in _currentBeats) {
      if (!chapterBeatsMap.containsKey(b.chapterId)) {
        chapterBeatsMap[b.chapterId] = [];
      }
      chapterBeatsMap[b.chapterId]!.add(b);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: themeColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'ROADMAP DETAIL',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.archive_outlined,
                        color: themeColors.textTertiary, size: 20),
                    tooltip: 'Archive Track',
                    onPressed: _handleArchive,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Roadmap Header Card
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _currentRoadmap.title,
                                  style: RythemTypography.headlineMedium.copyWith(
                                    color: themeColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  category.toUpperCase(),
                                  style: RythemTypography.labelSmall.copyWith(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Progress Bar & Beat Ratio
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$completedCount of $totalCount beats completed',
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textSecondary,
                                  fontSize: 12,
                                ),
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
                          const SizedBox(height: 8),
                          GlassProgressBar(
                            progress: progressRatio,
                            height: 6,
                          ),
                          const SizedBox(height: 16),

                          // Attach Resource Action
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'Attach Resource',
                                  icon: Icons.link_rounded,
                                  variant: GlassButtonVariant.secondary,
                                  onPressed: _showAttachResourceDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Chapters Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CHAPTERS & CURRICULUM FLOW',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '${widget.chapters.length} Chapters',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chapter Accordion List (First chapter open by default)
                    if (widget.chapters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'No chapters found in this track.\nAttach a YouTube resource or add modules.',
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...List.generate(widget.chapters.length, (i) {
                        final chapter = widget.chapters[i];
                        final beats = chapterBeatsMap[chapter.id] ?? [];
                        final isFirstChapter = (i == 0);

                        return ChapterAccordion(
                          chapter: chapter,
                          beats: beats,
                          initialExpanded: isFirstChapter,
                          onBeatToggled: _handleBeatToggle,
                          onBeatTapped: _openFocusSession,
                          onFlagBeat: (beat) {
                            ConfusingBeatDialog.show(context, beat: beat);
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
