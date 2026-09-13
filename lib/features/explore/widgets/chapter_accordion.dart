import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/database/models/chapter_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';

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
  final void Function(BeatEntity beat) onBeatTapped;
  final void Function(BeatEntity beat)? onFlagBeat;
  final void Function(BeatEntity beat)? onAttachResource;

  const ChapterAccordion({
    super.key,
    required this.chapter,
    required this.beats,
    this.initialExpanded = false,
    required this.onBeatToggled,
    required this.onBeatTapped,
    this.onFlagBeat,
    this.onAttachResource,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0x08000000),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x14000000),
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
                        Row(
                          children: [
                            Text(
                              widget.chapter.title,
                              style: RythemTypography.titleMedium.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

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
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.beats.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final beat = widget.beats[index];
                            return _AccordionBeatTile(
                              beat: beat,
                              themeColors: themeColors,
                              isDark: isDark,
                              onToggle: (val) => widget.onBeatToggled(beat, val),
                              onTap: () => widget.onBeatTapped(beat),
                              onFlag: widget.onFlagBeat != null
                                  ? () => widget.onFlagBeat!(beat)
                                  : null,
                              onAttachResource: widget.onAttachResource != null
                                  ? () => widget.onAttachResource!(beat)
                                  : null,
                            );
                          },
                        ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _AccordionBeatTile extends StatelessWidget {
  final BeatEntity beat;
  final RythemColorTokens themeColors;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final VoidCallback? onFlag;
  final VoidCallback? onAttachResource;

  const _AccordionBeatTile({
    required this.beat,
    required this.themeColors,
    required this.isDark,
    required this.onToggle,
    required this.onTap,
    this.onFlag,
    this.onAttachResource,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.015),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? themeColors.glassBorder : const Color(0x10000000),
            width: 0.7,
          ),
        ),
        child: Row(
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
                  duration: const Duration(milliseconds: 180),
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
                  child: beat.isCompleted
                      ? Icon(
                          Icons.check,
                          size: 13,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Beat Title & Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (beat.sourceUrl == null || beat.sourceUrl!.isEmpty) ...[
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
                        const SizedBox(width: 5),
                      ] else ...[
                        Icon(
                          Icons.link_rounded,
                          size: 11,
                          color: themeColors.textSecondary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'linked',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '•',
                          style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                        ),
                        const SizedBox(width: 5),
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
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: themeColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
