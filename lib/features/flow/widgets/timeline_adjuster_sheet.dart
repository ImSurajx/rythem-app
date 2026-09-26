import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/models/roadmap_entity.dart';
import '../../../../core/pacing/models/pacing_budget.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';

/// Modal bottom sheet allowing guilt-free, flexible timeline recalibration.
/// Users can extend by +7, +14, +30 days, pick a custom calendar date, or switch to Open Pace.
class TimelineAdjusterSheet extends StatefulWidget {
  final RoadmapEntity roadmap;
  final PacingBudget pacingBudget;
  final ValueChanged<DateTime?> onTargetDateSelected;

  const TimelineAdjusterSheet({
    super.key,
    required this.roadmap,
    required this.pacingBudget,
    required this.onTargetDateSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required RoadmapEntity roadmap,
    required PacingBudget pacingBudget,
    required ValueChanged<DateTime?> onTargetDateSelected,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TimelineAdjusterSheet(
        roadmap: roadmap,
        pacingBudget: pacingBudget,
        onTargetDateSelected: onTargetDateSelected,
      ),
    );
  }

  @override
  State<TimelineAdjusterSheet> createState() => _TimelineAdjusterSheetState();
}

class _TimelineAdjusterSheetState extends State<TimelineAdjusterSheet> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.roadmap.targetCompletionDate;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No Deadline (Open Pace)';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  double _calculateNewPace(DateTime target) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = target.difference(today).inDays;
    if (days <= 0) return widget.pacingBudget.remainingEffort;
    return widget.pacingBudget.remainingEffort / days;
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _selectedDate != null && _selectedDate!.isAfter(now)
        ? _selectedDate!
        : now.add(const Duration(days: 14));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Colors.white,
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Colors.black,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.mediumImpact();
      widget.onTargetDateSelected(picked);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _applyExtensionDays(int days) {
    HapticFeedback.mediumImpact();
    final base = _selectedDate ?? DateTime.now();
    final newDate = base.add(Duration(days: days));
    widget.onTargetDateSelected(newDate);
    Navigator.of(context).pop();
  }

  void _applyOpenPace() {
    HapticFeedback.mediumImpact();
    widget.onTargetDateSelected(null);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = RythemColors.of(context);
    final currentTarget = widget.roadmap.targetCompletionDate;
    final projected = widget.pacingBudget.projectedCompletionDate;
    final velocity = widget.pacingBudget.recentVelocity;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xE6121520) : const Color(0xF2FFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(context).padding.bottom,
          ),
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

              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0x28FFFFFF) : const Color(0x14000000),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(Icons.auto_graph_rounded, size: 18, color: themeColors.textPrimary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TIMELINE ADJUSTER',
                        style: RythemTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: themeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: themeColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                'Adjust your target finish date based on your real-life schedule. No backlog debt, no guilt.',
                style: RythemTypography.bodySmall.copyWith(
                  color: themeColors.textSecondary,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 16),

              // GPS ETA Live Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Target',
                          style: RythemTypography.labelSmall.copyWith(color: themeColors.textSecondary),
                        ),
                        Text(
                          _formatDate(currentTarget),
                          style: RythemTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Projected Finish (ETA)',
                          style: RythemTypography.labelSmall.copyWith(color: themeColors.textSecondary),
                        ),
                        Text(
                          _formatDate(projected),
                          style: RythemTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Velocity',
                          style: RythemTypography.labelSmall.copyWith(color: themeColors.textSecondary),
                        ),
                        Text(
                          '${velocity > 0 ? velocity.toStringAsFixed(1) : '1.0'} lessons / active day',
                          style: RythemTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'QUICK EXTENSIONS',
                style: RythemTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  color: themeColors.textSecondary,
                ),
              ),

              const SizedBox(height: 10),

              // +7 Days Preset
              _TimelinePresetTile(
                title: '+7 Days Extension',
                subtitle: _presetSubtitle(7, currentTarget),
                icon: Icons.add_circle_outline_rounded,
                isDark: isDark,
                themeColors: themeColors,
                onTap: () => _applyExtensionDays(7),
              ),

              const SizedBox(height: 8),

              // +14 Days Preset
              _TimelinePresetTile(
                title: '+14 Days Extension',
                subtitle: _presetSubtitle(14, currentTarget),
                icon: Icons.add_circle_outline_rounded,
                isDark: isDark,
                themeColors: themeColors,
                onTap: () => _applyExtensionDays(14),
              ),

              const SizedBox(height: 8),

              // Custom Date Picker Tile
              _TimelinePresetTile(
                title: 'Pick Custom Calendar Date',
                subtitle: 'Choose an exact target date on the calendar',
                icon: Icons.calendar_month_rounded,
                isDark: isDark,
                themeColors: themeColors,
                onTap: _pickCustomDate,
              ),

              const SizedBox(height: 8),

              // Open Pace Mode (No Deadline)
              _TimelinePresetTile(
                title: 'Switch to Open Pace',
                subtitle: 'Learn without any target deadline or ETA tracking',
                icon: Icons.all_inclusive_rounded,
                isDark: isDark,
                themeColors: themeColors,
                onTap: _applyOpenPace,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _presetSubtitle(int days, DateTime? currentTarget) {
    final base = currentTarget ?? DateTime.now();
    final newTarget = base.add(Duration(days: days));
    final newPace = _calculateNewPace(newTarget);
    return 'New target: ${_formatDate(newTarget)} • Aim for ~${newPace.toStringAsFixed(1)} lessons/day';
  }
}

class _TimelinePresetTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDark;
  final RythemColorTokens themeColors;
  final VoidCallback onTap;

  const _TimelinePresetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDark,
    required this.themeColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0x28FFFFFF) : const Color(0x14000000),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, size: 18, color: themeColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RythemTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: themeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: RythemTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: themeColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: themeColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
