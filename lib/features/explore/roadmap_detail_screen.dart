import 'dart:async';
import 'dart:ui';
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
import 'package:rythem_app/core/utils/resource_launcher.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';
import 'package:rythem_app/core/widgets/glass_toast.dart';
import 'package:rythem_app/features/flow/confusing_beat_dialog.dart';
import 'package:rythem_app/features/flow/session_detail_screen.dart';
import 'package:rythem_app/features/flow/split_task_sheet.dart';
import 'widgets/add_topic_sheet.dart';
import 'widgets/add_chapter_sheet.dart';
import '../../core/navigation/smooth_page_route.dart';
import 'widgets/chapter_accordion.dart';
import '../flow/widgets/timeline_adjuster_sheet.dart';
import '../../core/pacing/models/pacing_budget.dart';
import '../../core/ingestion/services/resource_sync_service.dart';

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
  final Set<String>? todaysBeatIds;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final Future<void> Function(BeatEntity beat)? onToggleFocusBeat;
  final Future<void> Function(RoadmapEntity roadmap)? onArchiveRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onRestoreRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onDeleteRoadmap;
  final Future<void> Function(String roadmapId, String resourceUrl, {String? chapterId})? onAttachResource;
  final Future<void> Function(String beatId, String resourceUrl)? onAttachResourceToBeat;
  final Future<ResourceSyncResult> Function(RoadmapEntity roadmap, {String? overrideUrl})? onSyncResource;
  final Future<void> Function(BeatEntity beat, int totalParts)? onSplitBeat;
  final Future<void> Function(BeatEntity beat)? onIncrementBeatPart;
  final Future<void> Function(BeatEntity beat)? onDecrementBeatPart;
  final Future<void> Function(RoadmapEntity roadmap, DateTime? newTargetDate)? onUpdateTargetDate;
  final PacingBudget? pacingBudget;
  final Set<String>? revisionShelfBeatIds;
  final void Function(BeatEntity beat)? onMarkForRevision;

  const RoadmapDetailScreen({
    super.key,
    required this.roadmap,
    required this.chapters,
    required this.beats,
    this.todaysBeatIds,
    required this.onBeatToggled,
    this.onToggleFocusBeat,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onDeleteRoadmap,
    this.onAttachResource,
    this.onAttachResourceToBeat,
    this.onSyncResource,
    this.onSplitBeat,
    this.onIncrementBeatPart,
    this.onDecrementBeatPart,
    this.onUpdateTargetDate,
    this.pacingBudget,
    this.revisionShelfBeatIds,
    this.onMarkForRevision,
  });

  @override
  State<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends State<RoadmapDetailScreen> {
  late RoadmapEntity _currentRoadmap;
  late List<ChapterEntity> _currentChapters;
  late List<BeatEntity> _currentBeats;

  late Set<String> _todaysBeatIds;

  String _formatDate(DateTime? date) {
    if (date == null) return 'No Deadline (Open Pace)';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  final _roadmapRepo = RoadmapRepository();
  final _chapterRepo = ChapterRepository();
  final _beatRepo = BeatRepository();
  StreamSubscription<DatabaseEvent>? _eventSub;
  bool _isAttaching = false;
  bool _isSyncing = false;
  final _syncService = ResourceSyncService();

  @override
  void initState() {
    super.initState();
    _currentRoadmap = widget.roadmap;
    _currentChapters = List.from(widget.chapters);
    _currentBeats = List.from(widget.beats);
    _todaysBeatIds = Set<String>.from(widget.todaysBeatIds ?? const {});

    _eventSub = DatabaseEventBus.instance.stream.listen((_) {
      _reloadFromDb();
    });
    _reloadFromDb();
  }

  Future<void> _handleToggleFocus(BeatEntity beat) async {
    setState(() {
      if (_todaysBeatIds.contains(beat.id)) {
        _todaysBeatIds.remove(beat.id);
      } else {
        _todaysBeatIds.add(beat.id);
      }
    });
    if (widget.onToggleFocusBeat != null) {
      await widget.onToggleFocusBeat!(beat);
    }
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

  Future<void> _handleSplitBeat(BeatEntity beat, int totalParts) async {
    if (widget.onSplitBeat != null) {
      await widget.onSplitBeat!(beat, totalParts);
    } else {
      await _beatRepo.updateBeatParts(beat.id, totalParts);
    }
    if (mounted) {
      await _reloadFromDb();
      if (mounted) {
        showGlassToast(
          context,
          totalParts > 1
              ? 'Split into $totalParts parts'
              : 'Reset to single task',
          icon: Icons.call_split_rounded,
        );
      }
    }
  }

  Future<void> _handleIncrementBeatPart(BeatEntity beat) async {
    if (widget.onIncrementBeatPart != null) {
      await widget.onIncrementBeatPart!(beat);
    } else {
      await _beatRepo.incrementBeatPart(beat.id);
    }
    if (mounted) {
      await _reloadFromDb();
    }
  }

  Future<void> _handleDecrementBeatPart(BeatEntity beat) async {
    if (widget.onDecrementBeatPart != null) {
      await widget.onDecrementBeatPart!(beat);
    } else {
      await _beatRepo.decrementBeatPart(beat.id);
    }
    if (mounted) {
      await _reloadFromDb();
    }
  }

  void _openAddTopicSheet(ChapterEntity chapter) {
    AddTopicSheet.show(
      context,
      chapter: chapter,
      roadmapId: _currentRoadmap.id,
      beatRepo: _beatRepo,
      onTopicSaved: (_) => _reloadFromDb(),
    );
  }

  void _openEditTopicSheet(BeatEntity beat) {
    final chapter = _currentChapters.where((c) => c.id == beat.chapterId).firstOrNull;
    if (chapter == null) return;
    AddTopicSheet.show(
      context,
      chapter: chapter,
      roadmapId: _currentRoadmap.id,
      existingBeat: beat,
      beatRepo: _beatRepo,
      onTopicSaved: (_) => _reloadFromDb(),
    );
  }

  Future<void> _handleDeleteBeat(BeatEntity beat) async {
    HapticFeedback.mediumImpact();
    await _beatRepo.deleteBeat(beat.id);
    if (mounted) {
      await _reloadFromDb();
      if (mounted) {
        showGlassToast(
          context,
          'Deleted "${beat.title}"',
          icon: Icons.delete_outline_rounded,
        );
      }
    }
  }

  void _openAddChapterSheet() {
    AddChapterSheet.show(
      context,
      roadmapId: _currentRoadmap.id,
      chapterRepo: _chapterRepo,
      onChapterSaved: (_) => _reloadFromDb(),
    );
  }

  void _openEditChapterSheet(ChapterEntity chapter) {
    AddChapterSheet.show(
      context,
      roadmapId: _currentRoadmap.id,
      existingChapter: chapter,
      chapterRepo: _chapterRepo,
      onChapterSaved: (_) => _reloadFromDb(),
    );
  }

  Future<void> _handleDeleteChapter(ChapterEntity chapter) async {
    HapticFeedback.heavyImpact();
    await _chapterRepo.deleteChapter(chapter.id);
    await _beatRepo.deleteBeatsByChapterId(chapter.id);
    if (mounted) {
      await _reloadFromDb();
      if (mounted) {
        showGlassToast(
          context,
          'Deleted chapter "${chapter.title}"',
          icon: Icons.delete_outline_rounded,
        );
      }
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
                            dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            style: TextStyle(color: themeColors.textPrimary, fontSize: 13),
                            icon: Icon(Icons.arrow_drop_down_rounded, color: themeColors.textSecondary),
                            items: _currentChapters.map((ch) {
                              return DropdownMenuItem<String>(
                                value: ch.id,
                                child: Text(
                                  ch.title,
                                  overflow: TextOverflow.ellipsis,
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

  Future<void> _handleSyncResource() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    showGlassToast(
      context,
      'Syncing with YouTube...',
      icon: Icons.sync_rounded,
    );
    try {
      final result = widget.onSyncResource != null
          ? await widget.onSyncResource!(_currentRoadmap)
          : await _syncService.syncRoadmapResource(roadmap: _currentRoadmap);
      await _reloadFromDb();
      if (mounted) {
        if (result.success) {
          showGlassToast(
            context,
            result.message ?? 'Synced with YouTube successfully!',
            icon: Icons.check_circle_outline_rounded,
            accentColor: const Color(0xFF10B981),
          );
        } else {
          showGlassToast(
            context,
            result.message ?? 'No YouTube resource found to sync',
            icon: Icons.info_outline_rounded,
            accentColor: const Color(0xFFF59E0B),
          );
        }
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Tracker', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Are you sure you want to delete "${_currentRoadmap.title}"? All chapters, beats, and progress will be permanently removed.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
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
                          const SizedBox(width: 6),
                          GlassButton(
                            label: 'Sync',
                            icon: Icons.sync_rounded,
                            height: 32,
                            variant: GlassButtonVariant.secondary,
                            isLoading: _isSyncing,
                            onPressed: _isSyncing ? () {} : _handleSyncResource,
                          ),
                          const SizedBox(width: 6),
                          GlassButton(
                            label: 'Add',
                            icon: Icons.link_rounded,
                            height: 32,
                            variant: GlassButtonVariant.secondary,
                            onPressed: _showAttachResourceDialog,
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

              // Scrollable Content with Pull-To-Refresh
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleSyncResource,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
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
                            ],
                          ),
                          // Pace & Target Date Row (Feature 4)
                          if (_currentRoadmap.targetCompletionDate != null || widget.pacingBudget != null) ...[
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: (widget.onUpdateTargetDate != null && widget.pacingBudget != null)
                                  ? () {
                                      TimelineAdjusterSheet.show(
                                        context,
                                        roadmap: _currentRoadmap,
                                        pacingBudget: widget.pacingBudget!,
                                        onTargetDateSelected: (newDate) async {
                                          await widget.onUpdateTargetDate!(_currentRoadmap, newDate);
                                          await _reloadFromDb();
                                        },
                                      );
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _currentRoadmap.targetCompletionDate == null
                                          ? Icons.all_inclusive_rounded
                                          : Icons.event_rounded,
                                      size: 16,
                                      color: const Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _currentRoadmap.targetCompletionDate == null
                                            ? 'Target: Open Pace (No Deadline)'
                                            : 'Target: ${_formatDate(_currentRoadmap.targetCompletionDate)}',
                                        style: RythemTypography.bodySmall.copyWith(
                                          color: themeColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    if (widget.onUpdateTargetDate != null && widget.pacingBudget != null) ...[
                                      Text(
                                        'Adjust',
                                        style: RythemTypography.labelSmall.copyWith(
                                          color: const Color(0xFF6366F1),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: Color(0xFF6366F1),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.06),
                                    ),
                                    child: Icon(
                                      nextPendingBeat.sourceUrl?.isNotEmpty == true
                                          ? (ResourceLauncher.isYouTube(nextPendingBeat.sourceUrl!)
                                              ? Icons.play_arrow_rounded
                                              : Icons.language_rounded)
                                          : Icons.play_arrow_rounded,
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
                                    label: nextPendingBeat.sourceUrl?.isNotEmpty == true
                                        ? (ResourceLauncher.isYouTube(nextPendingBeat.sourceUrl!)
                                            ? 'Watch'
                                            : 'Learn')
                                        : 'Start',
                                    icon: nextPendingBeat.sourceUrl?.isNotEmpty == true
                                        ? Icons.open_in_new_rounded
                                        : null,
                                    height: 34,
                                    variant: GlassButtonVariant.secondary,
                                    onPressed: () {
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
                          todaysBeatIds: _todaysBeatIds,
                          onToggleFocusBeat: _handleToggleFocus,
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
                          onSplitBeat: (beat) {
                            SplitTaskSheet.show(
                              context,
                              beat: beat,
                              onSave: (parts) => _handleSplitBeat(beat, parts),
                            );
                          },
                          onIncrementBeatPart: _handleIncrementBeatPart,
                          onDecrementBeatPart: _handleDecrementBeatPart,
                          onAddTopic: _openAddTopicSheet,
                          onEditBeat: _openEditTopicSheet,
                          onDeleteBeat: _handleDeleteBeat,
                          onEditChapter: _openEditChapterSheet,
                          onDeleteChapter: _handleDeleteChapter,
                          revisionShelfBeatIds: widget.revisionShelfBeatIds,
                          onMarkForRevision: widget.onMarkForRevision,
                        );
                      }),
                      const SizedBox(height: 16),
                      // Add Custom Chapter Button
                      GestureDetector(
                        onTap: _openAddChapterSheet,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.create_new_folder_rounded,
                                size: 18,
                                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add Custom Chapter',
                                style: RythemTypography.bodyMedium.copyWith(
                                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                  ],
                ),
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
