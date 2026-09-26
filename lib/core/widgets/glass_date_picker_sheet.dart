import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_button.dart';

/// Ultra-premium Liquid Glass Date Picker Sheet matching the Rythem design language.
/// Replaces Flutter's stock Android Material date picker dialog with an
/// Apple Health / Linear style frosted glass calendar.
class GlassDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String title;

  const GlassDatePickerSheet({
    super.key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.title = 'Select Date',
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Select Date',
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => GlassDatePickerSheet(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      ),
    );
  }

  @override
  State<GlassDatePickerSheet> createState() => _GlassDatePickerSheetState();
}

class _GlassDatePickerSheetState extends State<GlassDatePickerSheet> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
  }

  void _applyPreset(int daysFromToday) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day).add(Duration(days: daysFromToday));
    setState(() {
      _selectedDate = target;
      _displayedMonth = DateTime(target.year, target.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    // Monday is 1, Sunday is 7. Offset = weekday - 1
    final leadingSpaces = firstDayOfMonth.weekday - 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE612141C) : const Color(0xF2F8F9FC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x20000000),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x40FFFFFF) : const Color(0x30000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title.toUpperCase(),
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}',
                          style: RythemTypography.titleMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: themeColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick presets row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPresetChip('Today', 0, isDark, themeColors),
                      const SizedBox(width: 6),
                      _buildPresetChip('+1 Week', 7, isDark, themeColors),
                      const SizedBox(width: 6),
                      _buildPresetChip('+2 Weeks', 14, isDark, themeColors),
                      const SizedBox(width: 6),
                      _buildPresetChip('+1 Month', 30, isDark, themeColors),
                      const SizedBox(width: 6),
                      _buildPresetChip('+3 Months', 90, isDark, themeColors),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Month navigation row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0x18FFFFFF) : const Color(0x10000000),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: themeColors.textPrimary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        '${_months[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: themeColors.textPrimary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Weekday headers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _weekdays.map((day) {
                    return SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          day,
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Calendar days grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: leadingSpaces + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < leadingSpaces) {
                      return const SizedBox.shrink();
                    }
                    final dayNum = index - leadingSpaces + 1;
                    final cellDate = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);

                    final isSelected = cellDate.year == _selectedDate.year &&
                        cellDate.month == _selectedDate.month &&
                        cellDate.day == _selectedDate.day;

                    final isToday = cellDate.year == today.year &&
                        cellDate.month == today.month &&
                        cellDate.day == today.day;

                    final isPast = widget.firstDate != null && cellDate.isBefore(widget.firstDate!);
                    final isFuture = widget.lastDate != null && cellDate.isAfter(widget.lastDate!);
                    final isDisabled = isPast || isFuture;

                    return GestureDetector(
                      onTap: isDisabled
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedDate = cellDate;
                              });
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : isToday
                                    ? (isDark ? const Color(0x24FFFFFF) : const Color(0x14000000))
                                    : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isToday && !isSelected
                                ? Border.all(
                                    color: isDark ? Colors.white54 : Colors.black54,
                                    width: 1.2,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$dayNum',
                              style: RythemTypography.labelMedium.copyWith(
                                color: isSelected
                                    ? (isDark ? Colors.black : Colors.white)
                                    : isDisabled
                                        ? themeColors.textTertiary.withOpacity(0.35)
                                        : themeColors.textPrimary,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Confirm button
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Cancel',
                        variant: GlassButtonVariant.ghost,
                        height: 42,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GlassButton(
                        label: 'Confirm Date',
                        variant: GlassButtonVariant.primary,
                        height: 42,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(context, _selectedDate);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    int daysOffset,
    bool isDark,
    RythemColorTokens themeColors,
  ) {
    return GestureDetector(
      onTap: () => _applyPreset(daysOffset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0x20FFFFFF) : const Color(0x12000000),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: RythemTypography.labelSmall.copyWith(
            color: themeColors.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
