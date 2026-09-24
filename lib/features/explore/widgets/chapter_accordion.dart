import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/utils/resource_launcher.dart';

/// Collapsible Chapter Accordion widget for Roadmap Detail per `docs/design.md` §5:
/// - First chapter open by default
/// - Smooth animated chevron rotation
/// - Direct interactive checkboxes on beats
/// - Prominent `mentor extra` badge on unaligned topics
class ChapterAccordion extends StatefulWidget {
  final ChapterEntity chapter;
  final List<BeatEntity> beats;
  final bool initialExpanded;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;
  final void Function(BeatEntity beat)? onBeatTapped;
  final void Function(BeatEntity beat)? onFlagBeat;
  final void Function(BeatEntity beat)? onAttachResource;
  final void Function(ChapterEntity chapter)? onAttachResourceToChapter;
  final Future<void> Function(BeatEntity beat)? onConfirmMatch;
  final Future<void> Function(BeatEntity beat)? onRejectMatch;
  final Set<String>? delayedBeatIds;
  final void Function(BeatEntity beat)? onToggleDelay;
  final Set<String>? todaysBeatIds;
  final void Function(BeatEntity beat)? onToggleFocusBeat;
  final void Function(BeatEntity beat)? onSplitBeat;
  final void Function(BeatEntity beat)? onIncrementBeatPart;
  final void Function(BeatEntity beat)? onDecrementBeatPart;
  final void Function(ChapterEntity chapter)? onAddTopic;
  final void Function(BeatEntity beat)? onEditBeat;
  final void Function(BeatEntity beat)? onDeleteBeat;
  final void Function(ChapterEntity chapter)? onEditChapter;
  final void Function(ChapterEntity chapter)? onDeleteChapter;
  final Set<String>? revisionShelfBeatIds;
  final void Function(BeatEntity beat)? onMarkForRevision;

  const ChapterAccordion({
    super.key,
    required this.chapter,
    required this.beats,
    this.initialExpanded = false,
    required this.onBeatToggled,
    this.onBeatTapped,
    this.onFlagBeat,
    this.onAttachResource,
    this.onAttachResourceToChapter,
    this.onConfirmMatch,
    this.onRejectMatch,
    this.delayedBeatIds,
    this.onToggleDelay,
    this.todaysBeatIds,
    this.onToggleFocusBeat,
    this.onSplitBeat,
    this.onIncrementBeatPart,
    this.onDecrementBeatPart,
    this.onAddTopic,
    this.onEditBeat,
    this.onDeleteBeat,
    this.onEditChapter,
    this.onDeleteChapter,
    this.revisionShelfBeatIds,
    this.onMarkForRevision,
  });

  @override
  State<ChapterAccordion> createState() => _ChapterAccordionState();
}

class _ChapterAccordionState extends State<ChapterAccordion>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpand() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    final completedCount = widget.beats.where((b) => b.isCompleted).length;
    final totalCount = widget.beats.length;
    final progressRatio = totalCount > 0 ? (completedCount / totalCount) : 0.0;
    final gapsCount = widget.beats.where((b) => b.sourceUrl == null && !b.isMentorExtra).length;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.32)
                  : const Color(0xFF0E1420).withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                        const Color(0x0CFFFFFF),
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
          // Accordion Header Bar
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.chapter.title,
                          style: RythemTypography.titleMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '$completedCount of $totalCount beats',
                              style: RythemTypography.bodySmall.copyWith(
                                color: themeColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• ${(progressRatio * 100).toInt()}%',
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (gapsCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0x22F59E0B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$gapsCount gaps',
                                  style: const TextStyle(
                                    color: Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  if (widget.onAttachResourceToChapter != null) ...[
                    IconButton(
                      icon: Icon(
                        Icons.add_link_rounded,
                        size: 19,
                        color: themeColors.textSecondary,
                      ),
                      tooltip: 'Attach Resource to Subject',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => widget.onAttachResourceToChapter?.call(widget.chapter),
                    ),
                    const SizedBox(width: 4),
                  ],

                  if (widget.onEditChapter != null || widget.onDeleteChapter != null) ...[
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 19,
                        color: themeColors.textSecondary,
                      ),
                      tooltip: 'Chapter options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onSelected: (val) {
                        if (val == 'edit') widget.onEditChapter?.call(widget.chapter);
                        if (val == 'delete') widget.onDeleteChapter?.call(widget.chapter);
                      },
                      itemBuilder: (ctx) => [
                        if (widget.onEditChapter != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.drive_file_rename_outline_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Rename Chapter'),
                              ],
                            ),
                          ),
                        if (widget.onDeleteChapter != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Delete Chapter', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],

                  // Animated Rotating Chevron
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: themeColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Beats List
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                  child: Column(
                    children: [
                      if (widget.beats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'No beats in this chapter',
                              style: RythemTypography.bodySmall.copyWith(
                                color: themeColors.textTertiary,
                              ),
                            ),
                          ),
                        )
                      else
                        _buildCategorizedBeatsList(themeColors, isDark),
                      if (widget.onAddTopic != null) ...[
                        const SizedBox(height: 10),
                        _buildAddTopicButton(themeColors, isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            firstCurve: Curves.easeInOutCubic,
            secondCurve: Curves.easeInOutCubic,
            sizeCurve: Curves.easeInOutCubic,
          ),
        ],
      ),
    ),
  ),
),
      ),
    );
  }

  Widget _buildCategorizedBeatsList(RythemColorTokens themeColors, bool isDark) {
    // 1. Separate regular video beats from uncovered syllabus gaps
    final List<BeatEntity> videoBeats = [];
    final List<BeatEntity> gapBeats = [];

    // Ensure incoming beats are strictly sorted by sortOrder
    final sortedBeats = List<BeatEntity>.from(widget.beats)
      ..sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        if (cmp != 0) return cmp;
        return a.createdAt.compareTo(b.createdAt);
      });

    for (final beat in sortedBeats) {
      final isGap = beat.id.contains('_gap_') ||
          (beat.sourceUrl == null && beat.syllabusTopicId != null && !beat.isMentorExtra);
      if (isGap) {
        gapBeats.add(beat);
      } else {
        videoBeats.add(beat);
      }
    }

    // 2. Group video beats into contiguous chronological milestones
    final List<({String title, List<BeatEntity> beats})> milestoneSections = [];
    for (final beat in videoBeats) {
      final milestoneTitle = beat.syllabusTopicId ?? 'Core Curriculum';
      if (milestoneSections.isEmpty || milestoneSections.last.title != milestoneTitle) {
        milestoneSections.add((title: milestoneTitle, beats: [beat]));
      } else {
        milestoneSections.last.beats.add(beat);
      }
    }

    // If there is only 1 flat milestone and no gaps, render flat list
    if (milestoneSections.length <= 1 && gapBeats.isEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedBeats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _buildBeatItem(sortedBeats[index], themeColors, isDark),
      );
    }

    final sections = <Widget>[];

    // Render contiguous milestones in strict 1..N order
    for (int m = 0; m < milestoneSections.length; m++) {
      final milestone = milestoneSections[m];
      final beats = milestone.beats;
      final completed = beats.where((b) => b.isCompleted).length;

      sections.add(
        _TopicGroupSection(
          title: milestone.title,
          subtitle: '$completed/${beats.length} complete • ${beats.length} video${beats.length == 1 ? '' : 's'}',
          icon: Icons.menu_book_rounded,
          accentColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          themeColors: themeColors,
          isDark: isDark,
          children: beats.map((b) => _buildBeatItem(b, themeColors, isDark)).toList(),
        ),
      );
    }

    // Render Uncovered Syllabus Gaps at the bottom
    if (gapBeats.isNotEmpty) {
      final completed = gapBeats.where((b) => b.isCompleted).length;
      sections.add(
        _TopicGroupSection(
          title: '⚠️ Uncovered Syllabus Gaps',
          subtitle: '$completed/${gapBeats.length} complete • ${gapBeats.length} gap${gapBeats.length == 1 ? '' : 's'}',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFF59E0B),
          themeColors: themeColors,
          isDark: isDark,
          trailingAction: widget.onAttachResourceToChapter != null
              ? GestureDetector(
                  onTap: () => widget.onAttachResourceToChapter?.call(widget.chapter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_link_rounded, size: 12, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text(
                          'Fill Gap',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          children: gapBeats.map((b) => _buildBeatItem(b, themeColors, isDark)).toList(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildBeatItem(BeatEntity beat, RythemColorTokens themeColors, bool isDark) {
    final isInFocus = widget.todaysBeatIds?.contains(beat.id) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: BeatTile(
        beat: beat,
        themeColors: themeColors,
        isDark: isDark,
        isDelayed: widget.delayedBeatIds?.contains(beat.id) ?? false,
        isInFocus: isInFocus,
        onToggleFocus: widget.onToggleFocusBeat != null ? () => widget.onToggleFocusBeat!(beat) : null,
        onToggleDelay: widget.onToggleDelay != null ? () => widget.onToggleDelay!(beat) : null,
        onToggle: (val) => widget.onBeatToggled(beat, val),
        onSplit: widget.onSplitBeat != null ? () => widget.onSplitBeat!(beat) : null,
        onIncrementPart: widget.onIncrementBeatPart != null ? () => widget.onIncrementBeatPart!(beat) : null,
        onDecrementPart: widget.onDecrementBeatPart != null ? () => widget.onDecrementBeatPart!(beat) : null,
        onOpenResource: () => ResourceLauncher.openResource(
          context,
          url: beat.sourceUrl,
          title: beat.title,
        ),
        onFlag: widget.onFlagBeat != null ? () => widget.onFlagBeat!(beat) : null,
        onAttachResource: widget.onAttachResource != null ? () => widget.onAttachResource!(beat) : null,
        onConfirmMatch: widget.onConfirmMatch != null ? () => widget.onConfirmMatch!(beat) : null,
        onRejectMatch: widget.onRejectMatch != null ? () => widget.onRejectMatch!(beat) : null,
        onEdit: widget.onEditBeat != null ? () => widget.onEditBeat!(beat) : null,
        onDelete: widget.onDeleteBeat != null ? () => widget.onDeleteBeat!(beat) : null,
        isInRevisionShelf: widget.revisionShelfBeatIds?.contains(beat.id) ?? false,
        onMarkForRevision: widget.onMarkForRevision != null ? () => widget.onMarkForRevision!(beat) : null,
      ),
    );
  }

  Widget _buildAddTopicButton(RythemColorTokens themeColors, bool isDark) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onAddTopic?.call(widget.chapter);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 6),
            Text(
              'Add Topic to Chapter',
              style: RythemTypography.bodySmall.copyWith(
                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sub-chapter topic grouping section card with liquid glass styling
class _TopicGroupSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final RythemColorTokens themeColors;
  final bool isDark;
  final Widget? trailingAction;
  final List<Widget> children;

  const _TopicGroupSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.themeColors,
    required this.isDark,
    this.trailingAction,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0x1AFFFFFF),
                      const Color(0x0DFFFFFF),
                    ]
                  : [
                      const Color(0x70FFFFFF),
                      const Color(0x40FFFFFF),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? themeColors.glassBorder : const Color(0x10000000),
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                  child: Row(
                    children: [
                      Icon(icon, size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: RythemTypography.titleMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subtitle,
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                      if (trailingAction != null) ...[
                        const SizedBox(width: 8),
                        trailingAction!,
                      ],
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
        );
  }
}

class BeatTile extends StatelessWidget {
  final BeatEntity beat;
  final RythemColorTokens themeColors;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onOpenResource;
  final VoidCallback? onFlag;
  final VoidCallback? onAttachResource;
  final VoidCallback? onConfirmMatch;
  final VoidCallback? onRejectMatch;
  final bool isDelayed;
  final VoidCallback? onToggleDelay;
  final bool isInFocus;
  final VoidCallback? onToggleFocus;
  final VoidCallback? onRemoveFromFocus;
  final VoidCallback? onSplit;
  final VoidCallback? onIncrementPart;
  final VoidCallback? onDecrementPart;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isInRevisionShelf;
  final VoidCallback? onMarkForRevision;

  const BeatTile({
    super.key,
    required this.beat,
    required this.themeColors,
    required this.isDark,
    required this.onToggle,
    required this.onOpenResource,
    this.onFlag,
    this.onAttachResource,
    this.onConfirmMatch,
    this.onRejectMatch,
    this.isDelayed = false,
    this.onToggleDelay,
    this.isInFocus = false,
    this.onToggleFocus,
    this.onRemoveFromFocus,
    this.onSplit,
    this.onIncrementPart,
    this.onDecrementPart,
    this.onEdit,
    this.onDelete,
    this.isInRevisionShelf = false,
    this.onMarkForRevision,
  });

  @override
  Widget build(BuildContext context) {
    final showConfirmationPrompt = beat.matchConfidence != null &&
        beat.matchConfidence! < 0.70 &&
        beat.syllabusTopicId != null &&
        !beat.isMentorExtra;
    final hasResource = beat.sourceUrl != null && beat.sourceUrl!.trim().isNotEmpty;
    final isYt = hasResource && ResourceLauncher.isYouTube(beat.sourceUrl!);

    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0x22FFFFFF),
                      const Color(0x10FFFFFF),
                    ]
                  : [
                      const Color(0x80FFFFFF),
                      const Color(0x4DFFFFFF),
                    ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDelayed
                  ? (isDark ? const Color(0x80FFB300) : const Color(0x60F57C00))
                  : (isDark ? themeColors.glassBorder : const Color(0x18000000)),
              width: isDelayed ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.18)
                    : const Color(0xFF0E1420).withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
            // Interactive Checkbox / Multi-Part Progress Indicator
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                if (beat.isMultiPart && !beat.isCompleted && onIncrementPart != null) {
                  onIncrementPart!();
                } else {
                  onToggle(!beat.isCompleted);
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: beat.isMultiPart && !beat.isCompleted
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: beat.completedParts > 0
                              ? (isDark ? const Color(0x33818CF8) : const Color(0x204F46E5))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: beat.completedParts > 0
                                ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                : themeColors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${beat.completedParts}',
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: beat.completedParts > 0
                                ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                                : themeColors.textTertiary,
                          ),
                        ),
                      )
                    : AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: beat.isCompleted
                              ? themeColors.textPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: beat.isCompleted
                                ? themeColors.textPrimary
                                : themeColors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: beat.isCompleted ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),

            // Beat Title & Badges (Tapping content opens resource)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOpenResource,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Delayed Beat Badge
                        if (isDelayed) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x33FFB300) : const Color(0x20F57C00),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark ? const Color(0x80FFB300) : const Color(0x60F57C00),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.more_time_rounded,
                                  size: 10,
                                  color: isDark ? const Color(0xFFFFCA28) : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'DELAYED • LATER',
                                  style: RythemTypography.labelSmall.copyWith(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFFFCA28) : const Color(0xFFE65100),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Stacked Resource Badge (Resource 2, 3, etc.)
                        () {
                          final match = RegExp(r'_r(\d+)_').firstMatch(beat.id);
                          final rNum = match != null ? int.tryParse(match.group(1)!) : null;
                          if (rNum != null && rNum > 1) {
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withOpacity(0.4),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                'RESOURCE $rNum',
                                style: RythemTypography.labelSmall.copyWith(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }(),
                        // Mentor Extra Badge
                        if (beat.isMentorExtra) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? themeColors.glassBorderHighlight
                                    : Colors.black26,
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'MENTOR EXTRA',
                              style: RythemTypography.labelSmall.copyWith(
                                fontSize: 8,
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
                              fontWeight: FontWeight.w500,
                              fontSize: 12.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        if (!hasResource) ...[
                          Text(
                            'no resource linked yet',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary.withOpacity(0.75),
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '•',
                            style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                          ),
                        ] else ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isYt ? Icons.play_circle_outline_rounded : Icons.link_rounded,
                                size: 11,
                                color: themeColors.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isYt ? 'video' : 'linked',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textSecondary,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '•',
                            style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                          ),
                        ],
                        Text(
                          '${beat.effortWeight.toStringAsFixed(1)} effort',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 9.5,
                          ),
                        ),
                        if (beat.isMultiPart) ...[
                          Text(
                            '•',
                            style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                          ),
                          Text(
                            'part ${beat.completedParts}/${beat.totalParts}',
                            style: RythemTypography.labelSmall.copyWith(
                              color: beat.completedParts > 0
                                  ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                  : themeColors.textTertiary,
                              fontWeight: FontWeight.w700,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (beat.isMultiPart) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: List.generate(beat.totalParts, (index) {
                                final isDone = index < beat.completedParts;
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: EdgeInsets.only(
                                      right: index < beat.totalParts - 1 ? 2.5 : 0,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      color: isDone
                                          ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                                          : (isDark ? const Color(0x30FFFFFF) : const Color(0x20000000)),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(beat.partProgress * 100).toInt()}%',
                            style: RythemTypography.labelSmall.copyWith(
                              color: beat.completedParts > 0
                                  ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5))
                                  : themeColors.textTertiary,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (onAttachResource != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onAttachResource,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                    border: Border.all(
                      color: isDark ? themeColors.glassBorderHighlight : const Color(0x28000000),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    beat.sourceUrl?.isNotEmpty == true
                        ? Icons.link_rounded
                        : Icons.add_rounded,
                    size: 14,
                    color: themeColors.textPrimary,
                  ),
                ),
              ),
            ],

            if (onToggleDelay != null && !beat.isCompleted)
              IconButton(
                icon: Icon(
                  isDelayed ? Icons.restore_rounded : Icons.more_time_rounded,
                  size: 15,
                  color: isDelayed
                      ? (isDark ? const Color(0xFFFFCA28) : const Color(0xFFE65100))
                      : themeColors.textTertiary,
                ),
                onPressed: onToggleDelay,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: isDelayed ? 'Resume beat into active flow' : 'Delay beat for later',
              ),

            if (onSplit != null && !beat.isCompleted)
              IconButton(
                icon: Icon(
                  Icons.call_split_rounded,
                  size: 15,
                  color: beat.isMultiPart
                      ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                      : themeColors.textTertiary,
                ),
                onPressed: onSplit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: beat.isMultiPart
                    ? 'Part ${beat.completedParts} of ${beat.totalParts} (tap to edit parts)'
                    : 'Complete in parts (split task)',
              ),

            if (onToggleFocus != null && !beat.isCompleted)
              IconButton(
                icon: Icon(
                  isInFocus ? Icons.playlist_add_check_rounded : Icons.playlist_add_rounded,
                  size: 17,
                  color: isInFocus
                      ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
                      : themeColors.textTertiary,
                ),
                onPressed: onToggleFocus,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: isInFocus ? 'In Today\'s Focus (tap to remove)' : 'Add to Today\'s Focus',
              ),

            if (onRemoveFromFocus != null)
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: themeColors.textTertiary,
                ),
                onPressed: onRemoveFromFocus,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Remove from Today\'s Focus',
              ),

            if (onFlag != null)
              IconButton(
                icon: Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: themeColors.textTertiary,
                ),
                onPressed: onFlag,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              ),

            if (beat.isCompleted && onMarkForRevision != null)
              IconButton(
                icon: Icon(
                  isInRevisionShelf ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                  size: 15,
                  color: isInRevisionShelf
                      ? (isDark ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1))
                      : themeColors.textTertiary,
                ),
                onPressed: onMarkForRevision,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: isInRevisionShelf ? 'In Revision Shelf' : 'Mark for Revision',
              ),

            if (onEdit != null || onDelete != null || (beat.isCompleted && onMarkForRevision != null))
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 15,
                  color: themeColors.textTertiary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Topic options',
                onSelected: (val) {
                  if (val == 'edit') onEdit?.call();
                  if (val == 'delete') onDelete?.call();
                  if (val == 'revision') onMarkForRevision?.call();
                },
                itemBuilder: (ctx) => [
                  if (beat.isCompleted && onMarkForRevision != null)
                    PopupMenuItem(
                      value: 'revision',
                      child: Row(
                        children: [
                          Icon(
                            isInRevisionShelf ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                            size: 16,
                            color: isInRevisionShelf ? const Color(0xFF6366F1) : null,
                          ),
                          const SizedBox(width: 8),
                          Text(isInRevisionShelf ? 'Modify Revision Shelf' : 'Mark for Revision'),
                        ],
                      ),
                    ),
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Edit Topic'),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete Topic', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),

        // Inline Confirmation Prompt for Ambiguous Syllabus Matches (docs/design.md §5 & user-flow.md Flow 4)
        if (showConfirmationPrompt) ...[
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? themeColors.glassBorderHighlight : const Color(0x24000000),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Looks related to "${beat.syllabusTopicId}" — confirm?',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Confirm Action
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onConfirmMatch?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Confirm',
                      style: RythemTypography.labelSmall.copyWith(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Reject Action
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onRejectMatch?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Reject',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
  }
}
