import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/database_event_bus.dart';
import 'package:rythem_app/core/database/repositories/roadmap_repository.dart';
import 'package:rythem_app/core/database/repositories/chapter_repository.dart';
import 'package:rythem_app/core/database/repositories/beat_repository.dart';
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
  final Future<void> Function(String beatId, String resourceUrl)? onAttachResourceToBeat;

  const RoadmapDetailScreen({
    super.key,
    required this.roadmap,
    required this.chapters,
    required this.beats,
    required this.onBeatToggled,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onAttachResource,
    this.onAttachResourceToBeat,
  });

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late RoadmapEntity _currentRoadmap;
  late List<ChapterEntity> _currentChapters;
  late List<BeatEntity> _currentBeats;

  final _roadmapRepo = RoadmapRepository();
  final _chapterRepo = ChapterRepository();
  final _beatRepo = BeatRepository();
  StreamSubscription<DatabaseEvent>? _eventSub;
  bool _isAttaching = false;

  @override
  void initState() {
    super.initState();
    _currentRoadmap = widget.roadmap;
    _currentChapters = List.from(widget.chapters);
    _currentBeats = List.from(widget.beats);

    _eventSub = DatabaseEventBus.instance.stream.listen((_) {
      _reloadFromDb();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _reloadFromDb() async {
    try {
      final rm = await _roadmapRepo.getRoadmapById(_currentRoadmap.id);
      final chapters = await _chapterRepo.getChaptersByRoadmapId(_currentRoadmap.id);
      final beats = await _beatRepo.getBeatsByRoadmapId(_currentRoadmap.id);
      if (mounted) {
        setState(() {
          if (rm != null) _currentRoadmap = rm;
          _currentChapters = chapters;
          _currentBeats = beats;
        });
      }
    } catch (e) {
      debugPrint('Error reloading roadmap detail from DB: $e');
    }
  }

  @override
  void didUpdateWidget(RoadmapDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roadmap != widget.roadmap) {
      _currentRoadmap = widget.roadmap;
    }
    if (oldWidget.chapters != widget.chapters) {
      _currentChapters = List.from(widget.chapters);
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
                    label: _isAttaching ? 'Extracting & Ingesting...' : 'Attach & Ingest',
                    icon: Icons.link_rounded,
                    onPressed: _isAttaching
                        ? () {}
                        : () async {
                            final url = controller.text.trim();
                            if (url.isNotEmpty) {
                              Navigator.pop(ctx);
                              setState(() => _isAttaching = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Extracting playlist and dividing into chapters...'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              try {
                                await widget.onAttachResource?.call(_currentRoadmap.id, url);
                                await _reloadFromDb();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ingested ${_currentBeats.length} videos across ${_currentChapters.length} chapters!'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to attach resource: $e'),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isAttaching = false);
                              }
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

  void _showAttachResourceToBeatDialog(BeatEntity beat) {
    final controller = TextEditingController(text: beat.sourceUrl ?? '');
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
                    Expanded(
                      child: Text(
                        'ATTACH RESOURCE TO TOPIC',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: themeColors.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  beat.title,
                  style: RythemTypography.titleSmall.copyWith(
                    color: themeColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Link a YouTube video, playlist, timestamp link, or documentation specifically to this topic.',
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
                    hintText: 'https://youtube.com/watch?v=...&t=120s or resource link',
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
                    label: 'Attach to Topic',
                    icon: Icons.link_rounded,
                    onPressed: () {
                      final url = controller.text.trim();
                      if (url.isNotEmpty) {
                        Navigator.pop(ctx);
                        widget.onAttachResourceToBeat?.call(beat.id, url);
                        setState(() {
                          final idx = _currentBeats.indexWhere((b) => b.id == beat.id);
                          if (idx != -1) {
                            _currentBeats[idx] = _currentBeats[idx].copyWith(sourceUrl: url);
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Attached resource to "${beat.title}"'),
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
    final remainingCount = totalCount - completedCount;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final linkedCount = _currentBeats.where((b) => b.sourceUrl?.isNotEmpty == true).length;
    final unlinkedCount = totalCount - linkedCount;
    final category = _currentRoadmap.description?.isNotEmpty == true
        ? _currentRoadmap.description!
        : 'CURRICULUM TRACK';

    final nextPendingBeat = _currentBeats.where((b) => !b.isCompleted).firstOrNull;

    // Group beats by chapter
    final chapterBeatsMap = <String, List<BeatEntity>>{};
    for (final ch in _currentChapters) {
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
            // Top App Bar with Prominent "Add Resource" Button (Requirement 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: themeColors.textPrimary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ROADMAP DETAIL',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    label: 'Add Resource',
                    icon: Icons.link_rounded,
                    height: 36,
                    variant: GlassButtonVariant.primary,
                    onPressed: _showAttachResourceDialog,
                  ),
                  const SizedBox(width: 2),
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
                    // Roadmap Header & Stats Card
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
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Container(
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RythemTypography.labelSmall.copyWith(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: themeColors.textSecondary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),

                            ],
                          ),
                          const SizedBox(height: 14),

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

                          // Status Breakdown Chips (Requirement 2 & 10)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'REMAINING',
                                        style: RythemTypography.labelSmall.copyWith(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: themeColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$remainingCount topics',
                                        style: RythemTypography.labelSmall.copyWith(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: themeColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RESOURCES',
                                        style: RythemTypography.labelSmall.copyWith(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: themeColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$linkedCount linked${unlinkedCount > 0 ? ' ($unlinkedCount unlinked)' : ''}',
                                        style: RythemTypography.labelSmall.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: themeColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Attach Resource Action Button
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
                    const SizedBox(height: 16),

                    // "Up Next" Topic Highlight (Requirement 2)
                    if (nextPendingBeat != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.035),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorderHighlight : const Color(0x25000000),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                                color: themeColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UP NEXT',
                                    style: RythemTypography.labelSmall.copyWith(
                                      color: themeColors.textTertiary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Current Focus: ${nextPendingBeat.title}',
                                    style: RythemTypography.titleSmall.copyWith(
                                      color: themeColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GlassButton(
                              label: 'Start',
                              variant: GlassButtonVariant.secondary,
                              onPressed: () => _openFocusSession(nextPendingBeat),
                            ),
                          ],
                        ),
                      ),

                    // Chapters Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SYLLABUS & TOPIC FLOW',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          '${_currentChapters.length} Chapters • $totalCount Topics',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Chapter Accordion List with per-topic round (+) buttons
                    if (_currentChapters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Center(
                          child: Text(
                            'No topics found in this track.\nAttach a YouTube resource or import a syllabus outline.',
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      ...List.generate(_currentChapters.length, (i) {
                        final chapter = _currentChapters[i];
                        final beats = chapterBeatsMap[chapter.id] ?? [];
                        final isFirstChapter = (i == 0);

                        return ChapterAccordion(
                          chapter: chapter,
                          beats: beats,
                          initialExpanded: isFirstChapter,
                          onBeatToggled: _handleBeatToggle,
                          onBeatTapped: _openFocusSession,
                          onAttachResource: _showAttachResourceToBeatDialog,
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
