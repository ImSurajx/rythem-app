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
import '../../core/navigation/smooth_page_route.dart';
import '../../core/theme/animation_config.dart';
import '../flow/checkpoint_dialog.dart';
import '../flow/confusing_beat_dialog.dart';
import 'new_track_modal.dart';
import 'roadmap_detail_screen.dart';
import '../../core/widgets/smooth_dialog.dart';

enum ExploreTabSection { trackers, flagNotes }

class _FlaggedNoteItem {
  final RoadmapEntity roadmap;
  final ChapterEntity? chapter;
  final BeatEntity beat;
  final String notes;
  final int progress;

  const _FlaggedNoteItem({
    required this.roadmap,
    this.chapter,
    required this.beat,
    required this.notes,
    required this.progress,
  });
}

/// Explore Screen:
/// Divided into two ambient sections:
/// 1. Trackers: Curriculum roadmaps, progress, and "+ New Track" creation.
/// 2. Flag Notes: Comprehensive study notebook collecting all flagged checkpoint notes & reflections.
class ExploreScreen extends StatefulWidget {
  final List<RoadmapEntity> roadmaps;
  final Map<String, List<ChapterEntity>> chaptersByRoadmap;
  final Map<String, List<BeatEntity>> beatsByRoadmap;
  final Map<String, String> beatNotesMap;
  final Map<String, int> beatProgressMap;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final void Function(BeatEntity beat, int percentage, String notes)? onSaveCheckpoint;
  final void Function(BeatEntity beat, String note)? onSaveFlag;
  final Future<void> Function({
    required String title,
    required String category,
    DateTime? startDate,
    required DateTime targetDate,
    String? resourceUrl,
    String? syllabusText,
  }) onCreateTrack;
  final Future<void> Function(RoadmapEntity roadmap)? onArchiveRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onRestoreRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onDeleteRoadmap;
  final Future<void> Function(String roadmapId, String resourceUrl, {String? chapterId})? onAttachResource;
  final Future<void> Function(String beatId, String resourceUrl)? onAttachResourceToBeat;
  final void Function(RoadmapEntity roadmap)? onOpenRoadmapDetail;

  const ExploreScreen({
    super.key,
    required this.roadmaps,
    required this.chaptersByRoadmap,
    required this.beatsByRoadmap,
    this.beatNotesMap = const {},
    this.beatProgressMap = const {},
    required this.onBeatToggled,
    this.onSaveCheckpoint,
    this.onSaveFlag,
    required this.onCreateTrack,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onDeleteRoadmap,
    this.onAttachResource,
    this.onAttachResourceToBeat,
    this.onOpenRoadmapDetail,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  ExploreTabSection _currentSection = ExploreTabSection.trackers;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _notesSearchController = TextEditingController();
  String _notesSearchQuery = '';
  String? _selectedNotesRoadmapId;

  @override
  void dispose() {
    _searchController.dispose();
    _notesSearchController.dispose();
    super.dispose();
  }

  List<_FlaggedNoteItem> _getAllFlaggedNotes() {
    final list = <_FlaggedNoteItem>[];
    for (final rm in widget.roadmaps) {
      if (rm.status == 'archived') continue;
      final chapters = widget.chaptersByRoadmap[rm.id] ?? [];
      final chapterMap = {for (final c in chapters) c.id: c};
      final beats = widget.beatsByRoadmap[rm.id] ?? [];
      for (final b in beats) {
        final note = widget.beatNotesMap[b.id]?.trim();
        if (note != null && note.isNotEmpty) {
          list.add(_FlaggedNoteItem(
            roadmap: rm,
            chapter: chapterMap[b.chapterId],
            beat: b,
            notes: note,
            progress: widget.beatProgressMap[b.id] ?? 0,
          ));
        }
      }
    }
    return list;
  }

  Future<void> _confirmDeleteRoadmap(BuildContext context, RoadmapEntity roadmap) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final confirmed = await showSmoothDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Tracker',
          style: RythemTypography.titleMedium.copyWith(
            color: themeColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${roadmap.title}"? All chapters, beats, and progress will be permanently removed.',
          style: RythemTypography.bodyMedium.copyWith(
            color: themeColors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: RythemTypography.button.copyWith(
                color: themeColors.textTertiary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(
              'Delete',
              style: RythemTypography.button.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDeleteRoadmap != null) {
      await widget.onDeleteRoadmap!(roadmap);
    }
  }

  Future<void> _openRoadmapDetail(RoadmapEntity roadmap) async {
    HapticFeedback.lightImpact();
    if (widget.onOpenRoadmapDetail != null) {
      widget.onOpenRoadmapDetail!(roadmap);
      return;
    }

    final chapters = widget.chaptersByRoadmap[roadmap.id] ?? [];
    final beats = widget.beatsByRoadmap[roadmap.id] ?? [];

    await Navigator.of(context).push(
      SmoothPageRoute(
        child: RoadmapDetailScreen(
          roadmap: roadmap,
          chapters: chapters,
          beats: beats,
          beatNotesMap: widget.beatNotesMap,
          beatProgressMap: widget.beatProgressMap,
          onSaveCheckpoint: widget.onSaveCheckpoint,
          onSaveFlag: widget.onSaveFlag,
          onBeatToggled: widget.onBeatToggled,
          onArchiveRoadmap: widget.onArchiveRoadmap,
          onRestoreRoadmap: widget.onRestoreRoadmap,
          onDeleteRoadmap: widget.onDeleteRoadmap,
          onAttachResource: widget.onAttachResource,
          onAttachResourceToBeat: widget.onAttachResourceToBeat,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _openNewTrackModal() {
    HapticFeedback.lightImpact();
    NewTrackModal.show(
      context,
      onCreateTrack: widget.onCreateTrack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    // Filter active (non-archived) roadmaps
    final activeRoadmaps = widget.roadmaps.where((r) => r.status != 'archived').toList();

    // All user notes
    final allFlaggedNotes = _getAllFlaggedNotes();

    final filteredRoadmaps = activeRoadmaps.where((r) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final title = r.title.toLowerCase();
      final category = (r.description ?? '').toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Top Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPLORE',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currentSection == ExploreTabSection.trackers ? 'All Tracks' : 'Flag Notes',
                    style: RythemTypography.headlineMedium.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (_currentSection == ExploreTabSection.trackers)
                Tooltip(
                  message: 'New Track',
                  child: GestureDetector(
                    onTap: _openNewTrackModal,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: themeColors.textPrimary,
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF0E1420).withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Two-Section Segmented Navigation: Trackers vs Flag Notes
          Container(
            height: 42,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? themeColors.glassBorder : const Color(0x15000000),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSectionTabButton(
                    label: 'Trackers (${activeRoadmaps.length})',
                    icon: Icons.explore_outlined,
                    isSelected: _currentSection == ExploreTabSection.trackers,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentSection = ExploreTabSection.trackers);
                    },
                    themeColors: themeColors,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildSectionTabButton(
                    label: 'Flag Notes (${allFlaggedNotes.length})',
                    icon: Icons.flag_rounded,
                    isSelected: _currentSection == ExploreTabSection.flagNotes,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentSection = ExploreTabSection.flagNotes);
                    },
                    themeColors: themeColors,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // View Content based on selected section
          if (_currentSection == ExploreTabSection.trackers) ...[
            // Search Field
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  color: themeColors.textPrimary,
                  fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'Search tracks by title or category...',
                  hintStyle: TextStyle(
                    color: themeColors.textTertiary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search_rounded,
                      color: themeColors.textSecondary,
                      size: 19,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.clear,
                              color: themeColors.textTertiary,
                              size: 16,
                            ),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Track List
            if (filteredRoadmaps.isEmpty)
              _EmptyExploreState(
                searchQuery: _searchQuery,
                themeColors: themeColors,
                isDark: isDark,
                onNewTrack: _openNewTrackModal,
              )
            else
              ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRoadmaps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final roadmap = filteredRoadmaps[index];
                  final beats = widget.beatsByRoadmap[roadmap.id] ?? [];
                  final completedBeats = beats.where((b) => b.isCompleted).length;
                  final totalBeats = beats.length;
                  final totalEffort = beats.fold<double>(0.0, (acc, b) => acc + b.effortWeight);
                  final completedEffort = beats.where((b) => b.isCompleted).fold<double>(0.0, (acc, b) => acc + b.effortWeight);
                  final progressRatio = totalEffort > 0
                      ? (completedEffort / totalEffort)
                      : (totalBeats > 0 ? (completedBeats / totalBeats) : 0.0);

                  return _RoadmapExploreCard(
                    roadmap: roadmap,
                    completedBeats: completedBeats,
                    totalBeats: totalBeats,
                    completedEffort: completedEffort,
                    totalEffort: totalEffort,
                    progressRatio: progressRatio,
                    themeColors: themeColors,
                    isDark: isDark,
                    onTap: () => _openRoadmapDetail(roadmap),
                    onDelete: widget.onDeleteRoadmap != null
                        ? () => _confirmDeleteRoadmap(context, roadmap)
                        : null,
                  ).smoothEntrance(key: ValueKey('rm_${roadmap.id}'), index: index);
                },
              ),
          ] else ...[
            // Flag Notes Section
            _buildFlagNotesSection(
              notes: allFlaggedNotes,
              themeColors: themeColors,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required RythemThemeColors themeColors,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.12) : Colors.white)
              : Colors.transparent,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                  : themeColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlagNotesSection({
    required List<_FlaggedNoteItem> notes,
    required RythemThemeColors themeColors,
    required bool isDark,
  }) {
    if (notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0x1810B981) : const Color(0x12059669),
                  border: Border.all(
                    color: (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)).withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 28,
                  color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Flag Notes Yet',
                style: RythemTypography.titleMedium.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'When studying in Flow or Explore, tap the flag icon on any beat to record checkpoints, questions, or practice reflections.\n\nAll your reflections will gather here for easy review and revision.',
                textAlign: TextAlign.center,
                style: RythemTypography.bodySmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter by search query and selected roadmap
    final filteredNotes = notes.where((n) {
      if (_selectedNotesRoadmapId != null && n.roadmap.id != _selectedNotesRoadmapId) {
        return false;
      }
      if (_notesSearchQuery.isEmpty) return true;
      final q = _notesSearchQuery.toLowerCase();
      return n.beat.title.toLowerCase().contains(q) ||
          n.notes.toLowerCase().contains(q) ||
          n.roadmap.title.toLowerCase().contains(q) ||
          (n.chapter?.title.toLowerCase().contains(q) ?? false);
    }).toList();

    // Distinct roadmaps that have notes
    final roadmapsWithNotes = <String, RoadmapEntity>{};
    for (final n in notes) {
      roadmapsWithNotes[n.roadmap.id] = n.roadmap;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes Search Bar
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? themeColors.glassBorder : const Color(0x18000000),
            ),
          ),
          child: TextField(
            controller: _notesSearchController,
            onChanged: (val) => setState(() => _notesSearchQuery = val.trim()),
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              color: themeColors.textPrimary,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              isCollapsed: true,
              hintText: 'Search notes, topics, or reflections...',
              hintStyle: TextStyle(
                color: themeColors.textTertiary,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.search_rounded,
                  color: themeColors.textSecondary,
                  size: 19,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
              suffixIcon: _notesSearchQuery.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _notesSearchController.clear();
                        setState(() => _notesSearchQuery = '');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.clear, color: themeColors.textTertiary, size: 16),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 42),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter Pills if multiple roadmaps have notes
        if (roadmapsWithNotes.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildNoteFilterPill(
                  label: 'All Notes (${notes.length})',
                  isSelected: _selectedNotesRoadmapId == null,
                  onTap: () => setState(() => _selectedNotesRoadmapId = null),
                  themeColors: themeColors,
                  isDark: isDark,
                ),
                ...roadmapsWithNotes.values.map((rm) {
                  final count = notes.where((n) => n.roadmap.id == rm.id).length;
                  return _buildNoteFilterPill(
                    label: '${rm.title} ($count)',
                    isSelected: _selectedNotesRoadmapId == rm.id,
                    onTap: () => setState(() => _selectedNotesRoadmapId = rm.id),
                    themeColors: themeColors,
                    isDark: isDark,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        if (filteredNotes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Text(
                'No notes match "$_notesSearchQuery"',
                style: TextStyle(color: themeColors.textTertiary, fontSize: 13),
              ),
            ),
          )
        else
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredNotes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = filteredNotes[index];
              return _buildNoteCard(item, themeColors, isDark)
                  .smoothEntrance(key: ValueKey('note_${item.beat.id}'), index: index);
            },
          ),
      ],
    );
  }

  Widget _buildNoteFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required RythemThemeColors themeColors,
    required bool isDark,
  }) {
    final emeraldAccent = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? emeraldAccent.withOpacity(isDark ? 0.25 : 0.15)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? emeraldAccent : themeColors.glassBorder,
              width: isSelected ? 1.0 : 0.6,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? (isDark ? Colors.white : emeraldAccent) : themeColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoteCard(
    _FlaggedNoteItem item,
    RythemThemeColors themeColors,
    bool isDark,
  ) {
    final emeraldAccent = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Tracker Chip, Chapter Title, & Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: emeraldAccent.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: emeraldAccent.withOpacity(0.35), width: 0.7),
                ),
                child: Text(
                  item.roadmap.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: emeraldAccent,
                  ),
                ),
              ),
              if (item.chapter != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '• ${item.chapter!.title}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: themeColors.textTertiary,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(width: 6),
              if (item.beat.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: emeraldAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 10, color: emeraldAccent),
                      const SizedBox(width: 2),
                      Text(
                        'Completed',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: emeraldAccent),
                      ),
                    ],
                  ),
                )
              else if (item.progress > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '⚡ ${item.progress}%',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🚩 Flagged',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: themeColors.textTertiary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Beat Title
          Text(
            item.beat.title,
            style: RythemTypography.titleMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Reflection & Practice Notes Box
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.035) : Colors.black.withOpacity(0.025),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 3.5,
                      color: emeraldAccent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 14, color: emeraldAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'PRACTICE & REFLECTION NOTES',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: themeColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.notes,
                              style: TextStyle(
                                color: themeColors.textPrimary,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Row 4: Action Footer (Edit Note, Open in Track, Toggle Check)
          Row(
            children: [
              // Edit Note / Flag Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (item.progress > 0) {
                    CheckpointDialog.show(
                      context,
                      beat: item.beat,
                      initialPercent: item.progress,
                      initialNotes: item.notes,
                      onSaveCheckpoint: (pct, notes) {
                        widget.onSaveCheckpoint?.call(item.beat, pct, notes);
                        if (mounted) setState(() {});
                      },
                    );
                  } else {
                    ConfusingBeatDialog.show(
                      context,
                      beat: item.beat,
                      initialNote: item.notes,
                      onFlagSaved: (savedNote) {
                        if (widget.onSaveFlag != null) {
                          widget.onSaveFlag!(item.beat, savedNote);
                        } else {
                          widget.onSaveCheckpoint?.call(item.beat, 0, savedNote);
                        }
                        if (mounted) setState(() {});
                      },
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeColors.glassBorder, width: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.progress > 0 ? Icons.tune_rounded : Icons.flag_outlined,
                        size: 13,
                        color: themeColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        item.progress > 0 ? 'Edit Checkpoint' : 'Edit Flag',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Open in Track Button
              GestureDetector(
                onTap: () => _openRoadmapDetail(item.roadmap),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: themeColors.glassBorder, width: 0.7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.launch_rounded, size: 13, color: themeColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Open Track',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: themeColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // Quick Toggle Completion
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onBeatToggled(item.beat, !item.beat.isCompleted);
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.beat.isCompleted
                        ? emeraldAccent.withOpacity(0.2)
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                    border: Border.all(
                      color: item.beat.isCompleted ? emeraldAccent : themeColors.glassBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    item.beat.isCompleted ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: item.beat.isCompleted ? emeraldAccent : themeColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card per roadmap in Explore screen per `docs/design.md` §4
class _RoadmapExploreCard extends StatelessWidget {
  final RoadmapEntity roadmap;
  final int completedBeats;
  final int totalBeats;
  final double completedEffort;
  final double totalEffort;
  final double progressRatio;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _RoadmapExploreCard({
    required this.roadmap,
    required this.completedBeats,
    required this.totalBeats,
    required this.completedEffort,
    required this.totalEffort,
    required this.progressRatio,
    required this.themeColors,
    required this.isDark,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category = roadmap.description?.isNotEmpty == true
        ? roadmap.description!
        : 'CURRICULUM TRACK';

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title, Category Badge & Delete Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    roadmap.title,
                    style: RythemTypography.titleMedium.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: onDelete,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: themeColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar & Effort Points (e.g. "⚡ 12.5 of 35.0 pts • 7/21 topics")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${completedEffort.toStringAsFixed(1)} of ${totalEffort.toStringAsFixed(1)} pts',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                    Text(
                      ' • $completedBeats/$totalBeats topics',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textSecondary,
                        fontSize: 11,
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
              height: 5,
            ),
          ],
        ),
      );
  }
}

class _EmptyExploreState extends StatelessWidget {
  final String searchQuery;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onNewTrack;

  const _EmptyExploreState({
    required this.searchQuery,
    required this.themeColors,
    required this.isDark,
    required this.onNewTrack,
  });

  @override
  Widget build(BuildContext context) {
    final isSearching = searchQuery.isNotEmpty;

    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.explore_off_outlined,
              size: 38,
              color: themeColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'No Matching Tracks' : 'No Roadmaps Stored',
              style: RythemTypography.titleMedium.copyWith(
                color: themeColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearching
                  ? 'No curriculum found matching "$searchQuery". Try another keyword or create a new track.'
                  : 'Your curriculum catalog is empty. Create your first track to begin learning.',
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textTertiary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: 'Create New Track',
              icon: Icons.add_rounded,
              height: 48,
              variant: GlassButtonVariant.primary,
              onPressed: onNewTrack,
            ),
          ],
        ),
      ),
    );
  }
}
