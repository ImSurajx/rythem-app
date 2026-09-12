import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/glass_card.dart';
import 'package:rythem_app/core/widgets/glass_progress_bar.dart';
import 'confusing_beat_dialog.dart';

/// Focus Mode screen adhering to `docs/design.md` §3:
/// - Distraction-free: bottom dock is completely hidden
/// - Current roadmap + chapter label only
/// - Vertical sequential list of this chapter's beats
/// - One "Complete & Advance" action button that always advances to the next incomplete beat
class SessionDetailScreen extends StatefulWidget {
  final String roadmapTitle;
  final String chapterTitle;
  final List<BeatEntity> beats;
  final String? initialBeatId;
  final Future<void> Function(BeatEntity beat, bool isCompleted) onBeatToggled;

  const SessionDetailScreen({
    super.key,
    required this.roadmapTitle,
    required this.chapterTitle,
    required this.beats,
    this.initialBeatId,
    required this.onBeatToggled,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late List<BeatEntity> _currentBeats;
  late final ScrollController _scrollController;
  String? _activeBeatId;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentBeats = List.from(widget.beats);
    _scrollController = ScrollController();

    // Set initial active beat: either initialBeatId or first incomplete beat
    if (widget.initialBeatId != null &&
        _currentBeats.any((b) => b.id == widget.initialBeatId)) {
      _activeBeatId = widget.initialBeatId;
    } else {
      final firstIncomplete = _currentBeats.where((b) => !b.isCompleted).firstOrNull;
      _activeBeatId = firstIncomplete?.id ?? _currentBeats.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  BeatEntity? get _activeBeat =>
      _currentBeats.where((b) => b.id == _activeBeatId).firstOrNull;

  int get _completedCount => _currentBeats.where((b) => b.isCompleted).length;
  double get _progressRatio =>
      _currentBeats.isEmpty ? 0.0 : _completedCount / _currentBeats.length;

  Future<void> _handleBeatToggle(BeatEntity beat, bool newValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    HapticFeedback.selectionClick();

    await widget.onBeatToggled(beat, newValue);

    if (mounted) {
      setState(() {
        final index = _currentBeats.indexWhere((b) => b.id == beat.id);
        if (index != -1) {
          _currentBeats[index] = _currentBeats[index].copyWith(
            isCompleted: newValue,
            completedAt: newValue ? DateTime.now() : null,
            clearCompletedAt: !newValue,
          );
        }
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeAndAdvance() async {
    if (_isProcessing) return;
    final active = _activeBeat;
    if (active == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // 1. Mark active beat as completed if not already
    if (!active.isCompleted) {
      await widget.onBeatToggled(active, true);
      final index = _currentBeats.indexWhere((b) => b.id == active.id);
      if (index != -1) {
        _currentBeats[index] = _currentBeats[index].copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
      }
    }

    // 2. Find next incomplete beat in sequence
    final nextIncomplete = _currentBeats.where((b) => !b.isCompleted).firstOrNull;

    if (mounted) {
      setState(() {
        _activeBeatId = nextIncomplete?.id;
        _isProcessing = false;
      });

      if (nextIncomplete != null) {
        // Scroll to the next beat
        final nextIndex = _currentBeats.indexOf(nextIncomplete);
        _scrollController.animateTo(
          (nextIndex * 96.0).clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      } else {
        // All beats finished
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF222222),
            content: Text(
              'All chapter beats complete! Returning to Flow...',
              style: RythemTypography.bodySmall.copyWith(color: Colors.white),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    return Scaffold(
      backgroundColor: themeColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Focus Header (Roadmap & Chapter Label Only, per design.md §3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: themeColors.textPrimary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.roadmapTitle.toUpperCase(),
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textTertiary,
                                fontSize: 9.5,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.chapterTitle,
                              style: RythemTypography.titleMedium.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorder : const Color(0x14000000),
                          ),
                        ),
                        child: Text(
                          '$_completedCount of ${_currentBeats.length}',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: GlassProgressBar(
                    progress: _progressRatio,
                    height: 5,
                  ),
                ),

                const SizedBox(height: 8),

                // Vertical Sequence of Beats
                Expanded(
                  child: _currentBeats.isEmpty
                      ? Center(
                          child: Text(
                            'No beats found in this chapter',
                            style: RythemTypography.bodyMedium.copyWith(
                              color: themeColors.textTertiary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
                          itemCount: _currentBeats.length,
                          itemBuilder: (context, index) {
                            final beat = _currentBeats[index];
                            final isActive = beat.id == _activeBeatId;

                            return _FocusBeatTile(
                              beat: beat,
                              index: index + 1,
                              isActive: isActive,
                              themeColors: themeColors,
                              isDark: isDark,
                              onTap: () {
                                setState(() => _activeBeatId = beat.id);
                              },
                              onToggle: (val) => _handleBeatToggle(beat, val),
                              onFlag: () {
                                ConfusingBeatDialog.show(
                                  context,
                                  beat: beat,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),

            // Floating "Complete & Advance" Bottom Action Bar
            Positioned(
              left: 18,
              right: 18,
              bottom: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xCC161616) : const Color(0xEBFFFFFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? themeColors.glassBorder : const Color(0x28000000),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.4)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _activeBeat != null
                                    ? (_activeBeat!.isCompleted
                                        ? 'CURRENT BEAT COMPLETED'
                                        : 'FOCUSED BEAT')
                                    : 'SESSION FINISHED',
                                style: RythemTypography.labelSmall.copyWith(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: themeColors.textTertiary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _activeBeat?.title ?? 'All beats complete',
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        GlassButton(
                          label: _activeBeat == null || _completedCount == _currentBeats.length
                              ? 'Return to Flow'
                              : 'Complete & Advance',
                          icon: _activeBeat == null || _completedCount == _currentBeats.length
                              ? Icons.arrow_back_rounded
                              : Icons.check_circle_outline_rounded,
                          variant: GlassButtonVariant.primary,
                          onPressed: _completeAndAdvance,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusBeatTile extends StatelessWidget {
  final BeatEntity beat;
  final int index;
  final bool isActive;
  final RythemColorTokens themeColors;
  final bool isDark;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onFlag;

  const _FocusBeatTile({
    required this.beat,
    required this.index,
    required this.isActive,
    required this.themeColors,
    required this.isDark,
    required this.onTap,
    required this.onToggle,
    required this.onFlag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? (isDark ? themeColors.glassBorderHighlight : Colors.black87)
                  : (isDark ? themeColors.glassBorder : const Color(0x18000000)),
              width: isActive ? 1.4 : 0.8,
            ),
            color: isActive
                ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
                : Colors.transparent,
          ),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => onToggle(!beat.isCompleted),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22,
                    height: 22,
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
                            size: 15,
                            color: isDark ? Colors.black : Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Index circle
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: RythemTypography.labelSmall.copyWith(
                        fontSize: 9.5,
                        color: themeColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beat.title,
                        style: RythemTypography.bodyMedium.copyWith(
                          color: beat.isCompleted
                              ? themeColors.textTertiary
                              : themeColors.textPrimary,
                          decoration:
                              beat.isCompleted ? TextDecoration.lineThrough : null,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'IN FOCUS',
                                style: RythemTypography.labelSmall.copyWith(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: themeColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${beat.effortWeight.toStringAsFixed(1)} effort',
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 9.5,
                              color: themeColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Flag confusing action
                IconButton(
                  icon: Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: themeColors.textTertiary,
                  ),
                  onPressed: onFlag,
                  tooltip: 'Flag Confusion',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
