import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/ai/services/local_inference_service.dart';
import '../../../core/revision/models/revision_item.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_card.dart';
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
    // If no topics to revise, leave it empty as requested by user
    if (revisionItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.amber.withOpacity(0.18) : Colors.amber.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_edu_rounded,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'DAILY REVISION BOARD',
                            style: RythemTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: themeColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(isDark ? 0.22 : 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${revisionItems.length} DUE',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mathematically scheduled recall based on forgetting curve & flagged topics',
                        style: RythemTypography.caption.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Revision Item Cards
            Column(
              children: List.generate(revisionItems.length, (index) {
                final item = revisionItems[index];
                return _buildRevisionItemTile(context, item);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevisionItemTile(BuildContext context, RevisionItem item) {
    final isFlagged = item.isFlaggedWeak;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFlagged
              ? Colors.amber.withOpacity(isDark ? 0.35 : 0.25)
              : (isDark ? Colors.white10 : Colors.black12),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mastery / Count indicator
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: isFlagged
                      ? Colors.amber.withOpacity(0.2)
                      : (isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${item.revisionCount}x',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isFlagged ? Colors.amber : themeColors.textPrimary,
                    ),
                  ),
                ),
              ),

              // Topic details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: RythemTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: themeColors.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Tracker badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            item.roadmapTitle,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: themeColors.textSecondary,
                            ),
                          ),
                        ),
                        // Reason badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFlagged
                                ? Colors.amber.withOpacity(isDark ? 0.18 : 0.12)
                                : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            item.suggestedReason,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isFlagged ? FontWeight.w700 : FontWeight.w500,
                              color: isFlagged ? Colors.amber : themeColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Mark Revised check button
              IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onMarkRevised(item);
                },
                tooltip: 'Mark Revised Today',
                icon: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 22,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Breakdown button that triggers AI Mentor immediately
          GestureDetector(
            onTap: () => _showAiMentorBreakdownModal(context, item),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 14,
                    color: themeColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Quick Breakdown from AI Mentor',
                    style: RythemTypography.labelSmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: themeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: themeColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ],
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
