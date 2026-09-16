import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ai/services/local_inference_service.dart';
import '../../../core/revision/models/revision_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Clean, lightweight Today's Revision Suggestion Board.
/// Suggests 2-3 high-yield topics to revisit so the user doesn't forget.
/// If no topics need revision, renders empty (SizedBox.shrink).
class DailyRevisionBoard extends StatelessWidget {
  final List<RevisionItem> revisionItems;
  final ValueChanged<RevisionItem> onMarkRevised;
  final LocalInferenceService? inferenceService;
  final RythemColorTokens themeColors;
  final bool isDark;

  const DailyRevisionBoard({
    super.key,
    required this.revisionItems,
    required this.onMarkRevised,
    this.inferenceService,
    required this.themeColors,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (revisionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final dueCount = revisionItems.where((i) => !i.isCompletedToday).length;
    final isAllDone = revisionItems.isNotEmpty && dueCount == 0;
    final badgeColor = isAllDone ? const Color(0xFF10B981) : Colors.amber;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.28)
                  : const Color(0xFF0E1420).withOpacity(0.05),
              blurRadius: 16,
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
                          const Color(0x24FFFFFF),
                          const Color(0x12FFFFFF),
                          const Color(0x08FFFFFF),
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
                  width: 0.9,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clean Suggestion Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(isDark ? 0.2 : 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "TODAY'S REVISION",
                                  style: RythemTypography.titleMedium.copyWith(
                                    color: themeColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(isDark ? 0.22 : 0.15),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: badgeColor.withOpacity(isDark ? 0.4 : 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isAllDone ? 'ALL REVISED' : '$dueCount SUGGESTED',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Suggested topics based on your study pace • Refresh so you don\'t forget',
                          style: RythemTypography.caption.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(
                    height: 1,
                    color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                  ),

                  // 2-3 Focus Revision Tiles (matching BeatTile todo styling with strikethrough)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: revisionItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = revisionItems[index];
                      return _buildRevisionTile(context, item);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevisionTile(BuildContext context, RevisionItem item) {
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

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0x20FFFFFF),
                        const Color(0x0EFFFFFF),
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
                      ? Colors.black.withOpacity(0.14)
                      : const Color(0xFF0E1420).withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
                      duration: const Duration(milliseconds: 180),
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
                        duration: const Duration(milliseconds: 200),
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

                // Title, Track, and Contextual Reason
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.isFlaggedWeak) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.4),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                'WEAK TOPIC',
                                style: RythemTypography.labelSmall.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent,
                                  letterSpacing: 0.3,
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
                              color: isCompleted
                                  ? themeColors.textTertiary
                                  : (item.isFlaggedWeak ? Colors.amber : themeColors.textSecondary),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
