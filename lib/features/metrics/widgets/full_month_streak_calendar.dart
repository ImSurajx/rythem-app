import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/repositories/beat_log_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_card.dart';

const _emeraldAccent = Color(0xFF10B981);

/// Full interactive monthly calendar with GitHub-style contribution streak tiles,
/// month-to-month navigation, and current day highlighted with top-right beat badge.
/// 
/// Data is sourced directly from the SQLite `beat_logs` table (100% exportable/importable).
class FullMonthStreakCalendar extends StatefulWidget {
  final BeatLogRepository? beatLogRepo;
  final RythemColorTokens themeColors;
  final bool isDark;
  final int streakDays;
  final VoidCallback? onStreakTapped;

  const FullMonthStreakCalendar({
    super.key,
    this.beatLogRepo,
    required this.themeColors,
    required this.isDark,
    this.streakDays = 0,
    this.onStreakTapped,
  });

  @override
  State<FullMonthStreakCalendar> createState() => _FullMonthStreakCalendarState();
}

class _FullMonthStreakCalendarState extends State<FullMonthStreakCalendar> {
  late DateTime _displayedMonth;
  late final BeatLogRepository _repo;
  Map<String, int> _monthlyActivity = {};
  bool _isLoading = true;
  String? _selectedDateStr;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month, 1);
    _selectedDateStr = null;
    _repo = widget.beatLogRepo ?? BeatLogRepository();
    _loadMonthActivity();
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadMonthActivity() async {
    setState(() => _isLoading = true);
    try {
      final activity = await _repo.getActivityForMonth(
        _displayedMonth.year,
        _displayedMonth.month,
      );

      if (mounted) {
        setState(() {
          _monthlyActivity = activity;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _previousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
    });
    _loadMonthActivity();
  }

  void _nextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    });
    _loadMonthActivity();
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _weekDayHeaders = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = _formatDate(now);

    final firstDayWeekday = _displayedMonth.weekday; // 1 = Monday, 7 = Sunday
    final leadingEmptyDays = firstDayWeekday - 1;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final totalCells = leadingEmptyDays + daysInMonth;
    final totalRows = (totalCells / 7).ceil();

    int totalMonthBeats = 0;
    int activeDaysCount = 0;
    for (final count in _monthlyActivity.values) {
      if (count > 0) {
        totalMonthBeats += count;
        activeDaysCount++;
      }
    }

    final selectedCount = _selectedDateStr != null ? (_monthlyActivity[_selectedDateStr] ?? 0) : 0;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header & Navigation Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: widget.themeColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}'.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: RythemTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: widget.themeColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.streakDays > 0 ? _emeraldAccent : widget.themeColors.textTertiary)
                            .withOpacity(widget.isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (widget.streakDays > 0 ? _emeraldAccent : widget.themeColors.textTertiary)
                              .withOpacity(widget.isDark ? 0.4 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.streakDays > 0 ? '🔥 ${widget.streakDays}d streak' : '0d streak',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: widget.streakDays > 0 ? _emeraldAccent : widget.themeColors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Left / Right Month Navigators
                  GestureDetector(
                    onTap: _previousMonth,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: widget.themeColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _nextMonth,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: widget.themeColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monthly Summary Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalMonthBeats beats • $activeDaysCount active days',
                style: RythemTypography.caption.copyWith(
                  color: widget.themeColors.textTertiary,
                  fontSize: 11,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Less',
                    style: TextStyle(fontSize: 9, color: widget.themeColors.textTertiary),
                  ),
                  const SizedBox(width: 4),
                  _buildLegendTile(0),
                  const SizedBox(width: 3),
                  _buildLegendTile(1),
                  const SizedBox(width: 3),
                  _buildLegendTile(3),
                  const SizedBox(width: 3),
                  _buildLegendTile(5),
                  const SizedBox(width: 4),
                  Text(
                    'More',
                    style: TextStyle(fontSize: 9, color: widget.themeColors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weekday Labels
          Row(
            children: _weekDayHeaders.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: RythemTypography.labelSmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.themeColors.textTertiary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          if (_isLoading)
            const SizedBox(
              height: 160,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Column(
              children: List.generate(totalRows, (rowIdx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: List.generate(7, (colIdx) {
                      final cellIdx = (rowIdx * 7) + colIdx;
                      final dayNum = cellIdx - leadingEmptyDays + 1;

                      if (dayNum < 1 || dayNum > daysInMonth) {
                        return const Expanded(child: SizedBox(height: 38));
                      }

                      final date = DateTime(_displayedMonth.year, _displayedMonth.month, dayNum);
                      final dateStr = _formatDate(date);
                      final isToday = dateStr == todayStr;
                      final isSelected = dateStr == _selectedDateStr;
                      final count = _monthlyActivity[dateStr] ?? 0;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDateStr = dateStr);
                          },
                          child: _buildDayTile(
                            dayNum: dayNum,
                            count: count,
                            isToday: isToday,
                            isSelected: isSelected,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),

          // Interactive Selected Date Insight Pill
          if (_selectedDateStr != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark ? Colors.white12 : Colors.black12,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedCount > 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 14,
                    color: selectedCount > 0
                        ? (widget.isDark ? _emeraldAccent : Colors.teal)
                        : widget.themeColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDateStr == todayStr ? 'Today ($_selectedDateStr)' : _selectedDateStr!,
                    style: RythemTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.themeColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    selectedCount > 0
                        ? '$selectedCount beat${selectedCount == 1 ? '' : 's'} logged'
                        : 'No beats recorded',
                    style: RythemTypography.caption.copyWith(
                      color: selectedCount > 0
                          ? (widget.isDark ? Colors.white : Colors.black)
                          : widget.themeColors.textTertiary,
                      fontWeight: selectedCount > 0 ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildDayTile({
    required int dayNum,
    required int count,
    required bool isToday,
    required bool isSelected,
  }) {
    // Determine heat intensity (GitHub style) based strictly on real logged beat count
    Color tileColor;
    if (count >= 5) {
      tileColor = widget.isDark ? _emeraldAccent.withOpacity(0.85) : Colors.teal.shade700;
    } else if (count >= 3) {
      tileColor = widget.isDark ? _emeraldAccent.withOpacity(0.55) : Colors.teal.shade500;
    } else if (count >= 1) {
      tileColor = widget.isDark ? _emeraldAccent.withOpacity(0.28) : Colors.teal.shade200;
    } else {
      tileColor = widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
    }

    final textColor = count >= 3
        ? (widget.isDark ? Colors.black : Colors.white)
        : (isToday
            ? widget.themeColors.textPrimary
            : (count > 0 ? widget.themeColors.textPrimary : widget.themeColors.textSecondary));

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? (widget.isDark ? Colors.white70 : Colors.black87)
              : (isToday && count > 0
                  ? (widget.isDark ? Colors.white : Colors.black)
                  : (isToday
                      ? (widget.isDark ? Colors.white24 : Colors.black26)
                      : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.06)))),
          width: isSelected ? 1.4 : (isToday && count > 0 ? 1.5 : 0.8),
        ),
        boxShadow: isToday && count > 0
            ? [
                BoxShadow(
                  color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : (count >= 3
                ? [
                    BoxShadow(
                      color: _emeraldAccent.withOpacity(widget.isDark ? 0.2 : 0.1),
                      blurRadius: 4,
                    ),
                  ]
                : null),
      ),
      child: Stack(
        children: [
          // Day number in center
          Center(
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : (count > 0 ? FontWeight.w700 : FontWeight.w500),
                color: textColor,
              ),
            ),
          ),

          // Top right beat count badge - only show when beats are actually recorded
          if (count > 0)
            Positioned(
              top: 2,
              right: 2.5,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.black54 : Colors.white70,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.offline_bolt,
                  size: 7,
                  color: widget.isDark ? _emeraldAccent : Colors.teal.shade900,
                ),
              ),
            ),

          // Bottom indicator dot for today
          if (isToday)
            Positioned(
              bottom: 3,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: count > 0
                        ? (count >= 3 ? Colors.white : _emeraldAccent)
                        : (widget.isDark ? Colors.white70 : Colors.black87),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendTile(int count) {
    Color color;
    if (count >= 5) {
      color = widget.isDark ? _emeraldAccent.withOpacity(0.85) : Colors.teal.shade700;
    } else if (count >= 3) {
      color = widget.isDark ? _emeraldAccent.withOpacity(0.55) : Colors.teal.shade500;
    } else if (count >= 1) {
      color = widget.isDark ? _emeraldAccent.withOpacity(0.28) : Colors.teal.shade200;
    } else {
      color = widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    }

    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
