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

    return Container(
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
                  child: widget.beats.isEmpty
                      ? Padding(
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
                      : _buildCategorizedBeatsList(themeColors, isDark),
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
    );
  }

  Widget _buildCategorizedBeatsList(RythemColorTokens themeColors, bool isDark) {
    // 1. Partition beats into mapped topics, bonus/extras, and uncovered gaps
    final Map<String, List<BeatEntity>> topicMap = {};
    final List<BeatEntity> bonusBeats = [];
    final List<BeatEntity> gapBeats = [];

    for (final beat in widget.beats) {
      if ((beat.id.contains('_gap_') || (beat.sourceUrl == null && beat.syllabusTopicId != null)) &&
          !beat.isMentorExtra) {
        gapBeats.add(beat);
      } else if (beat.isMentorExtra) {
        bonusBeats.add(beat);
      } else {
        final topicName = beat.syllabusTopicId ?? 'Core Curriculum';
        topicMap.putIfAbsent(topicName, () => []).add(beat);
      }
    }

    final hasCategories = topicMap.length > 1 || bonusBeats.isNotEmpty || gapBeats.isNotEmpty;

    // If no distinct topics exist (e.g. flat unparsed course), render clean flat list
    if (!hasCategories) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.beats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) => _buildBeatItem(widget.beats[index], themeColors, isDark),
      );
    }

    final sections = <Widget>[];

    // Render topics in first-seen sequence
    int topicNumber = 1;
    for (final entry in topicMap.entries) {
      final topicName = entry.key;
      final beats = entry.value;
      final completed = beats.where((b) => b.isCompleted).length;

      sections.add(
        _TopicGroupSection(
          title: 'Topic $topicNumber: $topicName',
          subtitle: '$completed/${beats.length} complete • ${beats.length} video${beats.length == 1 ? '' : 's'}',
          icon: Icons.menu_book_rounded,
          accentColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
          themeColors: themeColors,
          isDark: isDark,
          children: beats.map((b) => _buildBeatItem(b, themeColors, isDark)).toList(),
        ),
      );
      topicNumber++;
    }

    // Render Bonus & Enrichment if present
    if (bonusBeats.isNotEmpty) {
      final completed = bonusBeats.where((b) => b.isCompleted).length;
      sections.add(
        _TopicGroupSection(
          title: '✦ Bonus & Enrichment',
          subtitle: '$completed/${bonusBeats.length} complete • ${bonusBeats.length} video${bonusBeats.length == 1 ? '' : 's'}',
          icon: Icons.auto_awesome_rounded,
          accentColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
          themeColors: themeColors,
          isDark: isDark,
          children: bonusBeats.map((b) => _buildBeatItem(b, themeColors, isDark)).toList(),
        ),
      );
    }

    // Render Uncovered Gaps if present
    if (gapBeats.isNotEmpty) {
      sections.add(
        _TopicGroupSection(
          title: '⚠️ Uncovered Syllabus Gaps',
          subtitle: '${gapBeats.length} topic${gapBeats.length == 1 ? '' : 's'} not in playlist',
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFF59E0B),
          themeColors: themeColors,
          isDark: isDark,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: BeatTile(
        beat: beat,
        themeColors: themeColors,
        isDark: isDark,
        isDelayed: widget.delayedBeatIds?.contains(beat.id) ?? false,
        onToggleDelay: widget.onToggleDelay != null ? () => widget.onToggleDelay!(beat) : null,
        onToggle: (val) => widget.onBeatToggled(beat, val),
        onOpenResource: () => ResourceLauncher.openResource(
          context,
          url: beat.sourceUrl,
          title: beat.title,
        ),
        onFlag: widget.onFlagBeat != null ? () => widget.onFlagBeat!(beat) : null,
        onAttachResource: widget.onAttachResource != null ? () => widget.onAttachResource!(beat) : null,
        onConfirmMatch: widget.onConfirmMatch != null ? () => widget.onConfirmMatch!(beat) : null,
        onRejectMatch: widget.onRejectMatch != null ? () => widget.onRejectMatch!(beat) : null,
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
  final List<Widget> children;

  const _TopicGroupSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.themeColors,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
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
                    ],
                  ),
                ),
                ...children,
              ],
            ),
          ),
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
  });

  @override
  Widget build(BuildContext context) {
    final showConfirmationPrompt = beat.matchConfidence != null &&
        beat.matchConfidence! < 0.70 &&
        beat.syllabusTopicId != null &&
        !beat.isMentorExtra;
    final hasResource = beat.sourceUrl != null && beat.sourceUrl!.trim().isNotEmpty;
    final isYt = hasResource && ResourceLauncher.isYouTube(beat.sourceUrl!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
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
            // Interactive Checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(!beat.isCompleted);
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AnimatedContainer(
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
                      ],
                    ),
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
  ),
),
    );
  }
}
