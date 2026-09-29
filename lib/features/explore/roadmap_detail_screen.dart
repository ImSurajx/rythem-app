import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/database_event_bus.dart';
import 'package:rythem_app/core/database/repositories/roadmap_repository.dart';
import 'package:rythem_app/core/database/repositories/chapter_repository.dart';
import 'package:rythem_app/core/database/repositories/beat_repository.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/utils/resource_launcher.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';
import 'package:rythem_app/core/widgets/glass_toast.dart';
import 'package:rythem_app/features/flow/confusing_beat_dialog.dart';
import 'package:rythem_app/features/flow/session_detail_screen.dart';
import '../../core/navigation/smooth_page_route.dart';
import '../../core/ingestion/services/curriculum_ingestion_service.dart';
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
  final Future<void> Function(RoadmapEntity roadmap)? onDeleteRoadmap;
  final Future<void> Function(String roadmapId, String resourceUrl, {String? chapterId})? onAttachResource;
  final Future<void> Function(String beatId, String resourceUrl)? onAttachResourceToBeat;

  const RoadmapDetailScreen({
    super.key,
    required this.roadmap,
    required this.chapters,
    required this.beats,
    required this.onBeatToggled,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onDeleteRoadmap,
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
  final _ingestionService = CurriculumIngestionService();
  StreamSubscription<DatabaseEvent>? _eventSub;
  bool _isAttaching = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _currentRoadmap = widget.roadmap;
    _currentChapters = List.from(widget.chapters);
    _currentBeats = List.from(widget.beats);

    _eventSub = DatabaseEventBus.instance.stream.listen((_) {
      _reloadFromDb();
    });
    _reloadFromDb();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  final Map<String, bool> _localPendingToggles = {};

  Future<void> _reloadFromDb() async {
    try {
      final rm = await _roadmapRepo.getRoadmapById(_currentRoadmap.id);
      final chapters = await _chapterRepo.getChaptersByRoadmapId(_currentRoadmap.id);
      final rawBeats = await _beatRepo.getBeatsByRoadmapId(_currentRoadmap.id);
      final beats = rawBeats.map((b) {
        if (_localPendingToggles.containsKey(b.id)) {
          final pending = _localPendingToggles[b.id]!;
          return b.copyWith(
            isCompleted: pending,
            completedAt: pending ? (b.completedAt ?? DateTime.now()) : null,
            clearCompletedAt: !pending,
          );
        }
        return b;
      }).toList();

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

  Future<void> _handleSyncResources() async {
    if (_isSyncing) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSyncing = true);
    showGlassToast(
      context,
      'Syncing & remapping all module playlists...',
      icon: Icons.sync_rounded,
      accentColor: const Color(0xFF6366F1),
    );

    try {
      final result = await _ingestionService
          .syncAndRemapRoadmapResources(_currentRoadmap.id)
          .timeout(const Duration(seconds: 45));
      await _reloadFromDb();
      DatabaseEventBus.instance.emit(DatabaseEvent(
        type: DatabaseEventType.roadmapUpdated,
        entityId: _currentRoadmap.id,
        roadmapId: _currentRoadmap.id,
      ));
      if (mounted) {
        showGlassToast(
          context,
          'Synced: ${result.updatedTopicsCount} topics remapped (${result.totalEffortPoints.toStringAsFixed(1)} pts total)! ⚡',
          icon: Icons.check_circle_outline_rounded,
          accentColor: const Color(0xFF10B981),
        );
      }
    } catch (e) {
      if (mounted) {
        showGlassToast(
          context,
          'Sync failed: $e',
          icon: Icons.error_outline_rounded,
          accentColor: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
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
      _reloadFromDb();
    }
  }

  Future<void> _handleBeatToggle(BeatEntity beat, bool isCompleted) async {
    _localPendingToggles[beat.id] = isCompleted;
    final updated = beat.copyWith(isCompleted: isCompleted);
    setState(() {
      final index = _currentBeats.indexWhere((b) => b.id == beat.id);
      if (index != -1) {
        _currentBeats[index] = updated;
      }
    });
    try {
      await widget.onBeatToggled(beat, isCompleted);
    } finally {
      _localPendingToggles.remove(beat.id);
      if (mounted) {
        await _reloadFromDb();
      }
    }
  }

  Future<void> _handleConfirmMatch(BeatEntity beat) async {
    HapticFeedback.mediumImpact();
    final updated = beat.copyWith(
      matchConfidence: 1.0,
      updatedAt: DateTime.now(),
    );
    await _beatRepo.updateBeat(updated);
    if (mounted) {
      showGlassToast(
        context,
        'Confirmed: "${beat.title}" linked to ${beat.syllabusTopicId}',
        icon: Icons.link_rounded,
      );
      await _reloadFromDb();
    }
  }

  Future<void> _handleRejectMatch(BeatEntity beat) async {
    HapticFeedback.lightImpact();
    final updated = beat.copyWith(
      matchConfidence: null,
      syllabusTopicId: null,
      isMentorExtra: true,
      updatedAt: DateTime.now(),
    );
    await _beatRepo.updateBeat(updated);
    if (mounted) {
      showGlassToast(
        context,
        'Marked "${beat.title}" as Mentor Extra',
        icon: Icons.psychology_outlined,
      );
      await _reloadFromDb();
    }
  }

  void _showAttachResourceDialog({String? initialChapterId}) {
    final controller = TextEditingController();
    String? selectedChapterId = initialChapterId ??
        (_currentChapters.isNotEmpty ? _currentChapters.first.id : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final theme = Theme.of(dialogCtx);
            final isDark = theme.brightness == Brightness.dark;
            final themeColors = isDark ? RythemColors.dark : RythemColors.light;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom,
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
                    // Top drag handle / pill slider
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.20) : Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
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
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Link a YouTube playlist or video. Videos are ingested in exact mentor sequence while the AI audits benchmark syllabus topic coverage.',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentChapters.length > 1) ...[
                      Text(
                        'TARGET SUBJECT / MODULE',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: themeColors.glassBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedChapterId,
                            isExpanded: true,
                            menuMaxHeight: 300,
                            borderRadius: BorderRadius.circular(16),
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: RythemTypography.bodyMedium.copyWith(color: themeColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, color: themeColors.textSecondary, size: 20),
                            items: _currentChapters.map((ch) {
                              return DropdownMenuItem<String>(
                                value: ch.id,
                                child: Text(
                                  ch.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: RythemTypography.bodyMedium.copyWith(
                                    color: themeColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedChapterId = val);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'RESOURCE URL',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      style: RythemTypography.bodyMedium.copyWith(color: themeColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://youtube.com/playlist?list=... or video URL',
                        hintStyle: RythemTypography.bodySmall.copyWith(color: themeColors.textTertiary, fontSize: 12),
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
                        label: _isAttaching ? 'Ingesting Resource...' : 'Ingest Resource',
                        icon: Icons.link_rounded,
                        height: 48,
                        variant: GlassButtonVariant.secondary,
                        isLoading: _isAttaching,
                        onPressed: _isAttaching
                            ? () {}
                            : () async {
                                final url = controller.text.trim();
                                if (url.isNotEmpty) {
                                  Navigator.pop(dialogCtx);
                                  setState(() => _isAttaching = true);
                                  showGlassToast(
                                    context,
                                    'Extracting playlist and running AI audit...',
                                    icon: Icons.sync_rounded,
                                  );
                                  try {
                                    await widget.onAttachResource?.call(
                                      _currentRoadmap.id,
                                      url,
                                      chapterId: selectedChapterId,
                                    );
                                    await _reloadFromDb();
                                    if (mounted) {
                                      final targetCh = _currentChapters
                                          .where((c) => c.id == selectedChapterId)
                                          .firstOrNull;
                                      final targetChBeats = _currentBeats
                                          .where((b) => b.chapterId == selectedChapterId)
                                          .toList();
                                      final remainingGaps = targetChBeats
                                          .where((b) => b.sourceUrl == null || b.sourceUrl!.isEmpty)
                                          .length;
                                      final gapMsg = remainingGaps > 0
                                          ? ' ($remainingGaps syllabus gap${remainingGaps == 1 ? '' : 's'} remaining)'
                                          : ' (100% syllabus covered!)';
                                      showGlassToast(
                                        context,
                                        'Attached to ${targetCh?.title ?? "Subject"}!$gapMsg',
                                        icon: Icons.check_circle_outline_rounded,
                                        accentColor: const Color(0xFF10B981),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      showGlassToast(
                                        context,
                                        'Failed to attach resource: $e',
                                        icon: Icons.error_outline_rounded,
                                        accentColor: Colors.redAccent,
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
                  style: RythemTypography.bodyMedium.copyWith(color: themeColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=...&t=120s or resource link',
                    hintStyle: RythemTypography.bodySmall.copyWith(color: themeColors.textTertiary, fontSize: 12),
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
                        showGlassToast(
                          context,
                          'Attached resource to "${beat.title}"',
                          icon: Icons.link_rounded,
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

  Future<void> _confirmDeleteCurrentRoadmap() async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Tracker', style: RythemTypography.titleMedium.copyWith(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${_currentRoadmap.title}"? All chapters, beats, and progress will be permanently removed.',
          style: RythemTypography.bodyMedium.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: RythemTypography.button.copyWith(color: themeColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('Delete', style: RythemTypography.button.copyWith(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDeleteRoadmap != null && mounted) {
      final roadmap = _currentRoadmap;
      Navigator.of(context).pop(); // Pop detail screen
      await widget.onDeleteRoadmap!(roadmap);
    }
  }

  void _openFocusSession(BeatEntity targetBeat) {
    HapticFeedback.lightImpact();
    final chapter = widget.chapters.where((c) => c.id == targetBeat.chapterId).firstOrNull;
    final chapterBeats = _currentBeats.where((b) => b.chapterId == targetBeat.chapterId).toList();

    Navigator.of(context).push(
      SmoothPageRoute(
        child: SessionDetailScreen(
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
    final totalEffort = _currentBeats.fold<double>(0.0, (sum, b) => sum + b.effortWeight);
    final completedEffort = _currentBeats.where((b) => b.isCompleted).fold<double>(0.0, (sum, b) => sum + b.effortWeight);
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
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: themeColors.canvasGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Floating Frosted Glass Top Navigation Bar
              RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x30FFFFFF) : const Color(0x66FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : const Color(0xFF0E1420).withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded,
                                color: themeColors.textPrimary, size: 18),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _currentRoadmap.title,
                              style: RythemTypography.titleSmall.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Sync & Remap Resources',
                            child: GestureDetector(
                              onTap: _isSyncing ? null : _handleSyncResources,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                                  border: Border.all(
                                    color: isDark ? themeColors.glassBorderHighlight : const Color(0x28000000),
                                    width: 0.9,
                                  ),
                                ),
                                child: _isSyncing
                                    ? Center(
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.8,
                                            valueColor: AlwaysStoppedAnimation<Color>(themeColors.textPrimary),
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.sync_rounded,
                                        size: 16,
                                        color: themeColors.textPrimary,
                                      ),
                              ),
                            ),
                          ),
                          if (widget.onDeleteRoadmap != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _confirmDeleteCurrentRoadmap,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: themeColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${completedEffort.toStringAsFixed(1)} of ${totalEffort.toStringAsFixed(1)} pts completed',
                                    style: RythemTypography.bodySmall.copyWith(
                                      color: themeColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    ' • $completedCount/$totalCount topics',
                                    style: RythemTypography.bodySmall.copyWith(
                                      color: themeColors.textSecondary,
                                      fontSize: 11.5,
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
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.035),
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
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.035),
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.035),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'EFFORT',
                                        style: RythemTypography.labelSmall.copyWith(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: themeColors.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 13,
                                            color: themeColors.textSecondary,
                                          ),
                                          const SizedBox(width: 2),
                                          Expanded(
                                            child: Text(
                                              '${completedEffort.toStringAsFixed(1)}/${totalEffort.toStringAsFixed(1)}',
                                              style: RythemTypography.labelSmall.copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: themeColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Attach Resource Action Button (Primary Action)
                          Row(
                            children: [
                              Expanded(
                                child: GlassButton(
                                  label: 'Attach Resource',
                                  icon: Icons.link_rounded,
                                  height: 48,
                                  variant: GlassButtonVariant.primary,
                                  onPressed: _showAttachResourceDialog,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // "Up Next" Topic Highlight (Direct Resource Launch)
                    if (nextPendingBeat != null)
                      GestureDetector(
                        onTap: () {
                          if (nextPendingBeat.sourceUrl?.isNotEmpty == true) {
                            ResourceLauncher.openResource(
                              context,
                              url: nextPendingBeat.sourceUrl,
                              title: nextPendingBeat.title,
                            );
                          } else {
                            _openFocusSession(nextPendingBeat);
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          const Color(0x22FFFFFF),
                                          const Color(0x0EFFFFFF),
                                        ]
                                      : [
                                          const Color(0x88FFFFFF),
                                          const Color(0x4DFFFFFF),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? themeColors.glassBorderHighlight : const Color(0x25000000),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
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
                                  Tooltip(
                                    message: nextPendingBeat.sourceUrl?.isNotEmpty == true
                                        ? (ResourceLauncher.isYouTube(nextPendingBeat.sourceUrl!)
                                            ? 'Watch Video'
                                            : 'Open Resource')
                                        : 'Start Focus',
                                    child: GestureDetector(
                                      onTap: () {
                                        if (nextPendingBeat.sourceUrl?.isNotEmpty == true) {
                                          ResourceLauncher.openResource(
                                            context,
                                            url: nextPendingBeat.sourceUrl,
                                            title: nextPendingBeat.title,
                                          );
                                        } else {
                                          _openFocusSession(nextPendingBeat);
                                        }
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: themeColors.textPrimary,
                                          boxShadow: [
                                            BoxShadow(
                                              color: isDark ? Colors.black.withOpacity(0.25) : const Color(0xFF0E1420).withOpacity(0.12),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          size: 20,
                                          color: isDark ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                          onConfirmMatch: _handleConfirmMatch,
                          onRejectMatch: _handleRejectMatch,
                          onAttachResourceToChapter: (ch) {
                            _showAttachResourceDialog(initialChapterId: ch.id);
                          },
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
    ),
  );
}
}
