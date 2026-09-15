import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ai/services/local_inference_service.dart';
import '../../../core/revision/models/revision_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/markdown_content_view.dart';

/// Top-of-Flow Daily Revision Board powered by mathematical spaced repetition
/// and on-device AI concept explanations.
class DailyRevisionBoard extends StatelessWidget {
  final List<RevisionItem> revisionItems;
  final ValueChanged<RevisionItem> onMarkRevised;
  final LocalInferenceService inferenceService;
  final RythemColorTokens themeColors;
  final bool isDark;

  const DailyRevisionBoard({
    super.key,
    required this.revisionItems,
    required this.onMarkRevised,
    required this.inferenceService,
    required this.themeColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (revisionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.35)
                : const Color(0xFF0E1420).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
                // Interactive Header matching _TrackTodoListCard
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(isDark ? 0.2 : 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.history_edu_rounded,
                                  size: 15,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DAILY REVISION BOARD',
                                style: RythemTypography.titleMedium.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                          Builder(
                            builder: (context) {
                              final dueCount = revisionItems.where((i) => !i.isCompletedToday).length;
                              final isAllDone = revisionItems.isNotEmpty && dueCount == 0;
                              final badgeColor = isAllDone ? const Color(0xFF10B981) : Colors.amber;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(isDark ? 0.22 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: badgeColor.withOpacity(isDark ? 0.4 : 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  isAllDone ? 'COMPLETED' : '$dueCount DUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mathematical Spaced Repetition • Advancing Every Weak Topic to Strongest',
                        style: RythemTypography.caption.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  height: 1,
                  color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                ),

                // Todo-styled Revision Tiles matching _TrackTodoListCard and BeatTile
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: revisionItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = revisionItems[index];
                    return _buildRevisionTodoTile(context, item);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevisionTodoTile(BuildContext context, RevisionItem item) {
    final isCompleted = item.isCompletedToday;
    final strength = item.strength;
    Color badgeColor;
    switch (strength) {
      case TopicStrength.weak:
        badgeColor = const Color(0xFFEF4444);
        break;
      case TopicStrength.strengthening:
        badgeColor = Colors.amber;
        break;
      case TopicStrength.strong:
        badgeColor = const Color(0xFF3B82F6);
        break;
      case TopicStrength.strongest:
        badgeColor = const Color(0xFF10B981);
        break;
    }

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
              color: isCompleted
                  ? (isDark ? const Color(0x3010B981) : const Color(0x4010B981))
                  : (isDark ? themeColors.glassBorder : const Color(0x18000000)),
              width: isCompleted ? 1.0 : 0.8,
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
                  // Interactive Checkbox matching BeatTile exactly
                  GestureDetector(
                    key: Key('revision_check_button_${item.beatId}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onMarkRevised(item);
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
                          color: isCompleted
                              ? themeColors.textPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCompleted
                                ? themeColors.textPrimary
                                : themeColors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: isCompleted ? 1.0 : 0.0,
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

                  // Title & Metadata
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _showAiMentorBreakdownModal(context, item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Weak Topic Badge if flagged
                              if (item.isFlaggedWeak) ...[
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    'WEAK TOPIC',
                                    style: RythemTypography.labelSmall.copyWith(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.redAccent,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: RythemTypography.bodyMedium.copyWith(
                                    color: isCompleted
                                        ? themeColors.textTertiary
                                        : themeColors.textPrimary,
                                    decoration:
                                        isCompleted ? TextDecoration.lineThrough : null,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 5,
                            runSpacing: 2,
                            children: [
                              Text(
                                item.roadmapTitle,
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textSecondary,
                                  fontSize: 9.5,
                                ),
                              ),
                              Text(
                                '•',
                                style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeColor.withOpacity(isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: badgeColor.withOpacity(isDark ? 0.45 : 0.3),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  item.strengthLabel,
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                              Text(
                                '•',
                                style: TextStyle(color: themeColors.textTertiary, fontSize: 9),
                              ),
                              Text(
                                item.suggestedReason,
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textTertiary,
                                  fontSize: 9.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick breakdown brain action icon on right
                  GestureDetector(
                    onTap: () => _showAiMentorBreakdownModal(context, item),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorder : const Color(0x15000000),
                            width: 0.7,
                          ),
                        ),
                        child: Icon(
                          Icons.psychology_outlined,
                          size: 15,
                          color: themeColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              // AI Quick breakdown button matching test finder
              GestureDetector(
                onTap: () => _showAiMentorBreakdownModal(context, item),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32, top: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: Colors.amber.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Quick Breakdown from AI Mentor',
                        style: RythemTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
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
    );
  }

  void _showAiMentorBreakdownModal(BuildContext context, RevisionItem item) {
    HapticFeedback.lightImpact();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AiBreakdownSheet(
          item: item,
          inferenceService: inferenceService,
          isDark: isDark,
          themeColors: themeColors,
        );
      },
    );
  }
}

class _AiBreakdownSheet extends StatefulWidget {
  final RevisionItem item;
  final LocalInferenceService inferenceService;
  final bool isDark;
  final RythemColorTokens themeColors;

  const _AiBreakdownSheet({
    required this.item,
    required this.inferenceService,
    required this.isDark,
    required this.themeColors,
  });

  @override
  State<_AiBreakdownSheet> createState() => _AiBreakdownSheetState();
}

class _AiBreakdownSheetState extends State<_AiBreakdownSheet> {
  String? _explanation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBreakdown();
  }

  Future<void> _fetchBreakdown() async {
    try {
      final res = await widget.inferenceService.explainConfusingBeat(
        beatTitle: widget.item.title,
        roadmapTitle: widget.item.roadmapTitle,
        roadmapId: widget.item.roadmapId,
      );
      if (mounted) {
        setState(() {
          _explanation = res;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _explanation = 'Unable to generate on-device breakdown at this time.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: media.size.height * 0.8,
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, media.padding.bottom + 20),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xE6141519) : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: widget.isDark ? Colors.white12 : Colors.black12,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.psychology_outlined,
                      size: 20,
                      color: widget.themeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.title,
                          style: RythemTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: widget.themeColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'AI Mentor Concept Breakdown • ${widget.item.roadmapTitle}',
                          style: RythemTypography.caption.copyWith(
                            color: widget.themeColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: widget.themeColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Compiled Markdown Content
              if (_isLoading)
                const SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: MarkdownContentView(
                      content: _explanation ?? '',
                      isDark: widget.isDark,
                      themeColors: widget.themeColors,
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
