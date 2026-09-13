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
import 'new_track_modal.dart';
import 'roadmap_detail_screen.dart';

/// Explore Screen per `docs/design.md` §4:
/// - Search field
/// - One card per roadmap (title, category, progress bar, beat-ratio like "7 of 21")
/// - Single "+ new track" action
/// - Not contains: expanded chapter/beat lists (that's roadmap detail), any settings
class ExploreScreen extends StatefulWidget {
  final List<RoadmapEntity> roadmaps;
  final Map<String, List<ChapterEntity>> chaptersByRoadmap;
  final Map<String, List<BeatEntity>> beatsByRoadmap;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final Future<void> Function({
    required String title,
    required String category,
    required DateTime targetDate,
    String? resourceUrl,
    String? syllabusText,
  }) onCreateTrack;
  final Future<void> Function(RoadmapEntity roadmap)? onArchiveRoadmap;
  final Future<void> Function(RoadmapEntity roadmap)? onRestoreRoadmap;
  final Future<void> Function(String roadmapId, String resourceUrl)? onAttachResource;
  final Future<void> Function(String beatId, String resourceUrl)? onAttachResourceToBeat;

  const ExploreScreen({
    super.key,
    required this.roadmaps,
    required this.chaptersByRoadmap,
    required this.beatsByRoadmap,
    required this.onBeatToggled,
    required this.onCreateTrack,
    this.onArchiveRoadmap,
    this.onRestoreRoadmap,
    this.onAttachResource,
    this.onAttachResourceToBeat,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openRoadmapDetail(RoadmapEntity roadmap) {
    HapticFeedback.lightImpact();
    final chapters = widget.chaptersByRoadmap[roadmap.id] ?? [];
    final beats = widget.beatsByRoadmap[roadmap.id] ?? [];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoadmapDetailScreen(
          roadmap: roadmap,
          chapters: chapters,
          beats: beats,
          onBeatToggled: widget.onBeatToggled,
          onArchiveRoadmap: widget.onArchiveRoadmap,
          onRestoreRoadmap: widget.onRestoreRoadmap,
          onAttachResource: widget.onAttachResource,
          onAttachResourceToBeat: widget.onAttachResourceToBeat,
        ),
      ),
    );
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

    // Filter active (non-archived) roadmaps by search query
    final activeRoadmaps = widget.roadmaps.where((r) => r.status != 'archived').toList();

    final filteredRoadmaps = activeRoadmaps.where((r) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final title = r.title.toLowerCase();
      final category = (r.description ?? '').toLowerCase();
      return title.contains(query) || category.contains(query);
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & New Track Button
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
                    'Curricula & Tracks',
                    style: RythemTypography.headlineMedium.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              GlassButton(
                label: 'New Track',
                icon: Icons.add_rounded,
                variant: GlassButtonVariant.primary,
                onPressed: _openNewTrackModal,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Field per `design.md` §4
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
                height: 1.2,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search tracks by title or category...',
                hintStyle: TextStyle(
                  color: themeColors.textTertiary,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: themeColors.textSecondary,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 46,
                  minHeight: 46,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: themeColors.textTertiary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),

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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredRoadmaps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final roadmap = filteredRoadmaps[index];
                final beats = widget.beatsByRoadmap[roadmap.id] ?? [];
                final completedBeats = beats.where((b) => b.isCompleted).length;
                final totalBeats = beats.length;
                final progressRatio =
                    totalBeats > 0 ? (completedBeats / totalBeats) : 0.0;

                return _RoadmapExploreCard(
                  roadmap: roadmap,
                  completedBeats: completedBeats,
                  totalBeats: totalBeats,
                  progressRatio: progressRatio,
                  themeColors: themeColors,
                  isDark: isDark,
                  onTap: () => _openRoadmapDetail(roadmap),
                );
              },
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
  final double progressRatio;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onTap;

  const _RoadmapExploreCard({
    required this.roadmap,
    required this.completedBeats,
    required this.totalBeats,
    required this.progressRatio,
    required this.themeColors,
    required this.isDark,
    required this.onTap,
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
            // Title & Category Badge
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
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar & Beat Ratio (e.g. "7 of 21")
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$completedBeats of $totalBeats beats',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textSecondary,
                    fontSize: 11.5,
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
              onPressed: onNewTrack,
            ),
          ],
        ),
      ),
    );
  }
}
