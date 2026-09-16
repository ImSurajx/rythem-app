import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/ai/services/local_inference_service.dart';
import '../../../../core/database/models/roadmap_entity.dart';
import '../../../../core/pacing/models/pacing_budget.dart';
import '../../../../core/pacing/models/pacing_decision.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/glass_button.dart';

/// Non-punitive backlog adaptation sheet powered by math and on-device AI.
/// Presents intelligent diagnosis and guilt-free recalibration options when sustained lag is detected.
class BacklogDecisionSheet extends StatefulWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final List<RoadmapEntity> allRoadmaps;
  final LocalInferenceService? inferenceService;
  final ValueChanged<PacingDecision> onDecisionSelected;

  const BacklogDecisionSheet({
    super.key,
    required this.roadmap,
    required this.pacingBudget,
    this.allRoadmaps = const [],
    this.inferenceService,
    required this.onDecisionSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required RoadmapEntity roadmap,
    required PacingBudget pacingBudget,
    List<RoadmapEntity> allRoadmaps = const [],
    LocalInferenceService? inferenceService,
    required ValueChanged<PacingDecision> onDecisionSelected,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BacklogDecisionSheet(
        roadmap: roadmap,
        pacingBudget: pacingBudget,
        allRoadmaps: allRoadmaps,
        inferenceService: inferenceService,
        onDecisionSelected: onDecisionSelected,
      ),
    );
  }

  @override
  State<BacklogDecisionSheet> createState() => _BacklogDecisionSheetState();
}

class _BacklogDecisionSheetState extends State<BacklogDecisionSheet> {
  ShortfallDiagnosis? _diagnosis;
  bool _isLoadingDiagnosis = true;

  @override
  void initState() {
    super.initState();
    _loadAiDiagnosis();
  }

  Future<void> _loadAiDiagnosis() async {
    try {
      final service = widget.inferenceService ?? LocalInferenceService();
      final diag = await service.diagnoseShortfallAndRecommend(
        roadmapId: widget.roadmap.id,
        budget: widget.pacingBudget,
      );
      if (mounted) {
        setState(() {
          _diagnosis = diag;
          _isLoadingDiagnosis = false;
        });
      }
    } catch (_) {
      if (mounted) {
        final dailyPace = max(0.8, widget.pacingBudget.todayEffortShare);
        final deficitDays = (widget.pacingBudget.shortfallDebt / dailyPace).ceil();
        final recommendedDays = max(3, min(14, deficitDays == 0 ? 5 : deficitDays + 2));
        setState(() {
          _diagnosis = ShortfallDiagnosis(
            diagnosis:
                'Your momentum slowed across recent study days with a debt of ${widget.pacingBudget.shortfallDebt.toStringAsFixed(1)} effort units. Recalibrating your timeline (+$recommendedDays days) keeps learning sustainable and penalty-free.',
            rootCause:
                '${widget.pacingBudget.lagStreakDays} lagging days accumulated ${widget.pacingBudget.shortfallDebt.toStringAsFixed(1)} units of effort debt.',
            recommendedExtensionDays: recommendedDays,
            coreBeatsToFocus: widget.pacingBudget.todaysBeats.take(3).map((b) => b.title).toList(),
            optionalBeatsToDefer: const [],
            encouragement:
                'Rhythm shifts are a natural part of deep mastery. Recalibrating keeps learning sustainable and penalty-free.',
            shortfallDebt: widget.pacingBudget.shortfallDebt,
            velocityDeficit: widget.pacingBudget.velocityDeficit,
          );
          _isLoadingDiagnosis = false;
        });
      }
    }
  }

  void _handleSelectDecision(PacingDecision decision) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onDecisionSelected(decision);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    final otherRoadmaps = widget.allRoadmaps.where((r) => r.id != widget.roadmap.id).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14171A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Status Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: themeColors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'BACKLOG RECALIBRATION',
                        style: RythemTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: themeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.pacingBudget.lagStreakDays}d lag trend',
                      style: RythemTypography.labelSmall.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: themeColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Text(
                'Rythem evaluates past momentum mathematically and recalibrates your pace without penalties, guilt, or broken streaks.',
                style: RythemTypography.bodySmall.copyWith(
                  color: themeColors.textTertiary,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // AI Mentor Diagnosis Card (Maths + AI)
              if (_isLoadingDiagnosis) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Analyzing shortfall metrics with AI Mentor...',
                        style: RythemTypography.caption.copyWith(
                          color: themeColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (_diagnosis != null) ...[
                _buildAiMentorCard(
                  context: context,
                  themeColors: themeColors,
                  isDark: isDark,
                  diagnosis: _diagnosis!,
                ),
                const SizedBox(height: 16),
              ],

              // Manual Recalibration Options
              Text(
                'MANUAL OPTIONS',
                style: RythemTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 10),

              // Option 1: Extend Target Date
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.update_rounded,
                title: 'Push Target Date (+7 Days)',
                subtitle: 'Gently dilutes remaining effort across 7 extra calendar days to ease your daily load.',
                badge: 'RECOMMENDED',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _handleSelectDecision(const PacingDecision.extendDate(7));
                },
              ),
              const SizedBox(height: 12),

              // Option 2: Trim to Core Beats
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.filter_alt_outlined,
                title: 'Trim to Core Must-Do Beats',
                subtitle: 'Temporarily deprioritizes optional mentor extras, keeping you locked onto primary milestones.',
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _handleSelectDecision(const PacingDecision.trimCore());
                },
              ),
              const SizedBox(height: 12),

              // Option 3: Borrow Pace (if multiple tracks)
              if (otherRoadmaps.isNotEmpty) ...[
                _buildOptionCard(
                  context: context,
                  themeColors: themeColors,
                  isDark: isDark,
                  icon: Icons.swap_horiz_rounded,
                  title: 'Borrow Pace from "${otherRoadmaps.first.title}"',
                  subtitle: 'Redistributes effort share across tracks to protect momentum on this roadmap.',
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _handleSelectDecision(PacingDecision.borrow(otherRoadmaps.first.id));
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Option 4: Accept & Continue
              _buildOptionCard(
                context: context,
                themeColors: themeColors,
                isDark: isDark,
                icon: Icons.check_circle_outline_rounded,
                title: 'Accept & Keep Pace',
                subtitle: 'Dismiss this reminder. Your daily streak and current schedule remain completely intact.',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _handleSelectDecision(const PacingDecision.accept());
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiMentorCard({
    required BuildContext context,
    required RythemThemeColors themeColors,
    required bool isDark,
    required ShortfallDiagnosis diagnosis,
  }) {
    const emerald = Color(0xFF10B981);
    const lightGreen = Color(0xFF34D399);
    const softMint = Color(0xFF6EE7B7);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  emerald.withOpacity(0.20),
                  lightGreen.withOpacity(0.10),
                  Colors.transparent,
                ]
              : [
                  emerald.withOpacity(0.12),
                  lightGreen.withOpacity(0.06),
                  Colors.white,
                ],
        ),
        border: Border.all(
          color: isDark ? lightGreen.withOpacity(0.40) : emerald.withOpacity(0.32),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? emerald : lightGreen).withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: emerald.withOpacity(isDark ? 0.25 : 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: isDark ? lightGreen : emerald,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI MENTOR DIAGNOSIS',
                      style: RythemTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? softMint : const Color(0xFF047857),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: emerald.withOpacity(isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: emerald.withOpacity(isDark ? 0.4 : 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Debt: ${diagnosis.shortfallDebt.toStringAsFixed(1)} pts',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? softMint : const Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Text(
                  diagnosis.diagnosis,
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),

                if (diagnosis.coreBeatsToFocus.isNotEmpty) ...[
                  Text(
                    'High-Impact Core Focus:',
                    style: RythemTypography.caption.copyWith(
                      color: themeColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...diagnosis.coreBeatsToFocus.map(
                    (title) => Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              title,
                              style: RythemTypography.caption.copyWith(
                                color: themeColors.textPrimary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 1-Tap Auto Rebalance Button
                GlassButton(
                  label: 'Auto-Rebalance (+${diagnosis.recommendedExtensionDays} Days)',
                  icon: Icons.auto_fix_high_rounded,
                  variant: GlassButtonVariant.primary,
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    _handleSelectDecision(
                      PacingDecision.extendDate(diagnosis.recommendedExtensionDays),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required RythemThemeColors themeColors,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: themeColors.textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: RythemTypography.titleSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColors.actionPrimary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: themeColors.actionPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
