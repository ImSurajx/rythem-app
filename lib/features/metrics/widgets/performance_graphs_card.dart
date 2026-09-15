import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/repositories/beat_log_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_card.dart';

enum GraphMode {
  sevenDays,
  monthly,
  lifetime,
}

/// Unified Performance Graph Card combining:
/// 1. 7 Days (Original daily beat bar chart)
/// 2. Monthly (Stock-market style fluctuating line chart showing daily peaks & valleys)
/// 3. Lifetime (Cumulative stock-market / repo star trajectory curve)
class PerformanceGraphsCard extends StatefulWidget {
  final BeatLogRepository? beatLogRepo;
  final List<DailyBeatCount> recentActivity;
  final RythemColorTokens themeColors;
  final bool isDark;

  const PerformanceGraphsCard({
    super.key,
    this.beatLogRepo,
    required this.recentActivity,
    required this.themeColors,
    required this.isDark,
  });

  @override
  State<PerformanceGraphsCard> createState() => _PerformanceGraphsCardState();
}

class _PerformanceGraphsCardState extends State<PerformanceGraphsCard> {
  GraphMode _mode = GraphMode.sevenDays;
  late final BeatLogRepository _repo;
  List<DailyBeatCount> _allLifetimeLogs = [];
  Map<String, int> _monthDailyLogs = {};
  bool _isLoading = true;
  int? _scrubbedIndex;

  @override
  void initState() {
    super.initState();
    _repo = widget.beatLogRepo ?? BeatLogRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final monthData = await _repo.getActivityForMonth(now.year, now.month);
      final lifetimeData = await _repo.getAllDailyActivity();
      if (mounted) {
        setState(() {
          _monthDailyLogs = monthData;
          _allLifetimeLogs = lifetimeData;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String headerTitle;
    String headerSubtitle;
    IconData headerIcon;

    switch (_mode) {
      case GraphMode.sevenDays:
        headerTitle = '7-DAY BEAT RHYTHM';
        headerSubtitle = 'Daily completed beats over the past week';
        headerIcon = Icons.bar_chart_rounded;
        break;
      case GraphMode.monthly:
        headerTitle = 'MONTHLY PERFORMANCE';
        headerSubtitle = 'Stock-market rhythm showing daily momentum and velocity shifts';
        headerIcon = Icons.show_chart_rounded;
        break;
      case GraphMode.lifetime:
        headerTitle = 'LIFETIME STAR GROWTH';
        headerSubtitle = 'Cumulative knowledge growth curve inspired by GitHub star trajectories';
        headerIcon = Icons.auto_graph_rounded;
        break;
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with 3 Segmented Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      headerIcon,
                      size: 16,
                      color: widget.themeColors.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        headerTitle,
                        overflow: TextOverflow.ellipsis,
                        style: RythemTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: widget.themeColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Segmented Toggle with 3 modes
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(
                      title: '7 Days',
                      isSelected: _mode == GraphMode.sevenDays,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = GraphMode.sevenDays;
                          _scrubbedIndex = null;
                        });
                      },
                    ),
                    _buildToggleItem(
                      title: 'Monthly',
                      isSelected: _mode == GraphMode.monthly,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = GraphMode.monthly;
                          _scrubbedIndex = null;
                        });
                      },
                    ),
                    _buildToggleItem(
                      title: 'Lifetime Stars',
                      isSelected: _mode == GraphMode.lifetime,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _mode = GraphMode.lifetime;
                          _scrubbedIndex = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headerSubtitle,
            style: RythemTypography.caption.copyWith(
              color: widget.themeColors.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),

          // Graph View
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
          else if (_mode == GraphMode.sevenDays)
            _buildSevenDaysBarView()
          else if (_mode == GraphMode.monthly)
            _buildMonthlyStockMarketLineView()
          else
            _buildLifetimeStarGrowthView(),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (widget.isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.09))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          title,
          style: RythemTypography.labelSmall.copyWith(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
          ),
        ),
      ),
    );
  }

  // --- 1. Seven Days Bar Graph View (Preserving Original Look & Feel) ---
  Widget _buildSevenDaysBarView() {
    final activity = widget.recentActivity.isNotEmpty
        ? widget.recentActivity
        : List.generate(7, (i) {
            final d = DateTime.now().subtract(Duration(days: 6 - i));
            return DailyBeatCount(
              date: '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
              count: i == 6 ? 2 : (i % 2 == 0 ? 1 : 0),
            );
          });

    int maxCount = 4;
    for (final day in activity) {
      if (day.count > maxCount) maxCount = day.count;
    }

    final total7Days = activity.fold(0, (sum, d) => sum + d.count);
    final active7Days = activity.where((d) => d.count > 0).length;
    final avg7Days = (total7Days / 7.0).toStringAsFixed(1);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniMetric('7D BEATS', '$total7Days', widget.themeColors),
            _buildMiniMetric('AVG PACE', '$avg7Days /d', widget.themeColors),
            _buildMiniMetric('ACTIVE DAYS', '$active7Days / 7d', widget.themeColors),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(activity.length, (idx) {
              final day = activity[idx];
              final isToday = idx == activity.length - 1;
              final ratio = (day.count / maxCount).clamp(0.0, 1.0);
              final barHeight = (ratio * 68).clamp(day.count > 0 ? 12.0 : 5.0, 68.0);

              DateTime? parsed;
              try {
                parsed = DateTime.parse(day.date);
              } catch (_) {}
              const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final dayLabel = parsed != null ? weekDays[parsed.weekday - 1] : '?';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        day.count > 0 ? '${day.count}' : '',
                        style: RythemTypography.labelSmall.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isToday ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: barHeight,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          color: isToday
                              ? (widget.isDark ? Colors.white : Colors.black)
                              : (day.count > 0
                                  ? (widget.isDark ? Colors.white.withOpacity(0.35) : Colors.black.withOpacity(0.35))
                                  : (widget.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06))),
                          border: isToday
                              ? Border.all(
                                  color: widget.isDark ? Colors.white70 : Colors.black87,
                                  width: 1.2,
                                )
                              : null,
                          boxShadow: isToday && day.count > 0
                              ? [
                                  BoxShadow(
                                    color: widget.isDark ? Colors.white24 : Colors.black12,
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dayLabel,
                        style: RythemTypography.labelSmall.copyWith(
                          fontSize: 10,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // --- 2. Monthly Stock-Market Line View (Fluctuating line with peaks & valleys) ---
  Widget _buildMonthlyStockMarketLineView() {
    final now = DateTime.now();
    final daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final List<({String date, int count})> monthlyPoints = [];

    int peakVelocity = 0;
    int totalBeats = 0;
    int activeDays = 0;

    for (int day = 1; day <= daysInCurrentMonth; day++) {
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      int count = _monthDailyLogs[dateStr] ?? 0;

      // Provide reasonable mock points for current month if empty
      if (count == 0 && widget.recentActivity.isNotEmpty) {
        for (final rec in widget.recentActivity) {
          if (rec.date == dateStr) count = rec.count;
        }
      }

      if (count > peakVelocity) peakVelocity = count;
      totalBeats += count;
      if (count > 0) activeDays++;

      monthlyPoints.add((date: dateStr, count: count));
    }

    if (peakVelocity == 0) peakVelocity = 4;

    final selectedIndex = _scrubbedIndex != null && _scrubbedIndex! < monthlyPoints.length
        ? _scrubbedIndex!
        : (now.day - 1).clamp(0, monthlyPoints.length - 1);
    final selectedDay = monthlyPoints[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniMetric('TOTAL BEATS', '$totalBeats', widget.themeColors),
            _buildMiniMetric('PEAK VELOCITY', '$peakVelocity /d', widget.themeColors),
            _buildMiniMetric('ACTIVE DAYS', '$activeDays / ${now.day}d', widget.themeColors),
          ],
        ),
        const SizedBox(height: 18),

        // Stock Market Fluctuating Line Chart
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = details.localPosition;
            final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
            final newIdx = (ratio * (monthlyPoints.length - 1)).round();
            if (newIdx != _scrubbedIndex && newIdx < monthlyPoints.length) {
              HapticFeedback.selectionClick();
              setState(() => _scrubbedIndex = newIdx);
            }
          },
          child: SizedBox(
            height: 125,
            width: double.infinity,
            child: CustomPaint(
              painter: _StockMarketLineChartPainter(
                points: monthlyPoints.map((p) => p.count.toDouble()).toList(),
                maxVal: math.max(1, peakVelocity).toDouble(),
                selectedIndex: selectedIndex,
                isDark: widget.isDark,
                lineColor: widget.isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Scrubber Tooltip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedDay.date,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.themeColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: selectedDay.count > 0 ? const Color(0xFF10B981) : widget.themeColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '${selectedDay.count} beats completed',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: widget.themeColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 3. Lifetime Star Growth View (Repo Star Style) ---
  Widget _buildLifetimeStarGrowthView() {
    final rawLogs = _allLifetimeLogs.isNotEmpty ? _allLifetimeLogs : widget.recentActivity;
    final List<({String date, int cumulative})> cumulativePoints = [];
    int runningTotal = 0;

    for (final day in rawLogs) {
      runningTotal += day.count;
      cumulativePoints.add((date: day.date, cumulative: runningTotal));
    }

    if (cumulativePoints.isEmpty) {
      cumulativePoints.add((date: DateTime.now().toIso8601String().substring(0, 10), cumulative: 0));
    }

    final maxCumulative = math.max(1, cumulativePoints.last.cumulative);

    final selectedIndex = _scrubbedIndex != null && _scrubbedIndex! < cumulativePoints.length
        ? _scrubbedIndex!
        : cumulativePoints.length - 1;
    final selectedPoint = cumulativePoints[selectedIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniMetric('TOTAL STARS', '${cumulativePoints.last.cumulative} ⭐', widget.themeColors),
            _buildMiniMetric('TIMELINE DAYS', '${cumulativePoints.length}d', widget.themeColors),
            _buildMiniMetric('MILESTONES', '${(cumulativePoints.last.cumulative / 5).floor()} 🏆', widget.themeColors),
          ],
        ),
        const SizedBox(height: 18),

        GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = details.localPosition;
            final ratio = (local.dx / box.size.width).clamp(0.0, 1.0);
            final newIdx = (ratio * (cumulativePoints.length - 1)).round();
            if (newIdx != _scrubbedIndex && newIdx < cumulativePoints.length) {
              HapticFeedback.selectionClick();
              setState(() => _scrubbedIndex = newIdx);
            }
          },
          child: SizedBox(
            height: 125,
            width: double.infinity,
            child: CustomPaint(
              painter: _RepoStarChartPainter(
                points: cumulativePoints.map((p) => p.cumulative.toDouble()).toList(),
                maxVal: maxCumulative.toDouble(),
                selectedIndex: selectedIndex,
                isDark: widget.isDark,
                lineColor: widget.isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(
                    'Milestone at ${selectedPoint.date}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: widget.themeColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${selectedPoint.cumulative} cumulative beats',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: widget.themeColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value, RythemColorTokens themeColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RythemTypography.labelSmall.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: themeColors.textTertiary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: themeColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for Stock Market fluctuating line graph (up/down daily rhythm)
class _StockMarketLineChartPainter extends CustomPainter {
  final List<double> points;
  final double maxVal;
  final int selectedIndex;
  final bool isDark;
  final Color lineColor;

  _StockMarketLineChartPainter({
    required this.points,
    required this.maxVal,
    required this.selectedIndex,
    required this.isDark,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final stepX = points.length > 1 ? width / (points.length - 1) : width;

    final path = Path();
    final fillPath = Path();

    final List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = maxVal > 0 ? (points[i] / maxVal) : 0.0;
      final y = height - (normalizedY * (height - 24)) - 10;
      offsets.add(Offset(x, y));
    }

    path.moveTo(offsets.first.dx, offsets.first.dy);
    fillPath.moveTo(offsets.first.dx, height);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 1; i < offsets.length; i++) {
      path.lineTo(offsets[i].dx, offsets[i].dy);
      fillPath.lineTo(offsets[i].dx, offsets[i].dy);
    }

    fillPath.lineTo(offsets.last.dx, height);
    fillPath.close();

    // Fill gradient underneath (stock market area)
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withOpacity(isDark ? 0.25 : 0.18),
        lineColor.withOpacity(0.0),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Line stroke with sharp ticker segments
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Draw data points on days with completed beats
    for (int i = 0; i < points.length; i++) {
      if (points[i] > 0) {
        final dotPaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(offsets[i], 2.5, dotPaint);
      }
    }

    // Scrubber vertical indicator
    if (selectedIndex >= 0 && selectedIndex < offsets.length) {
      final selectedOffset = offsets[selectedIndex];

      final guidePaint = Paint()
        ..color = (isDark ? Colors.white30 : Colors.black26)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedOffset.dx, 0),
        Offset(selectedOffset.dx, height),
        guidePaint,
      );

      final outerGlow = Paint()
        ..color = lineColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 8, outerGlow);

      final dotPaint = Paint()
        ..color = isDark ? Colors.white : Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 4.5, dotPaint);

      final centerDot = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 2.5, centerDot);
    }
  }

  @override
  bool shouldRepaint(covariant _StockMarketLineChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points ||
        oldDelegate.isDark != isDark;
  }
}

/// Custom painter for GitHub repo stargazers style cumulative growth curve
class _RepoStarChartPainter extends CustomPainter {
  final List<double> points;
  final double maxVal;
  final int selectedIndex;
  final bool isDark;
  final Color lineColor;

  _RepoStarChartPainter({
    required this.points,
    required this.maxVal,
    required this.selectedIndex,
    required this.isDark,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final stepX = points.length > 1 ? width / (points.length - 1) : width;

    final path = Path();
    final fillPath = Path();

    final List<Offset> offsets = [];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = maxVal > 0 ? (points[i] / maxVal) : 0.0;
      final y = height - (normalizedY * (height - 18)) - 8;
      offsets.add(Offset(x, y));
    }

    path.moveTo(offsets.first.dx, offsets.first.dy);
    fillPath.moveTo(offsets.first.dx, height);
    fillPath.lineTo(offsets.first.dx, offsets.first.dy);

    for (int i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final curr = offsets[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
      fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    fillPath.lineTo(offsets.last.dx, height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        (isDark ? Colors.white : Colors.black).withOpacity(0.18),
        (isDark ? Colors.white : Colors.black).withOpacity(0.01),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    if (selectedIndex >= 0 && selectedIndex < offsets.length) {
      final selectedOffset = offsets[selectedIndex];

      final guidePaint = Paint()
        ..color = (isDark ? Colors.white30 : Colors.black26)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedOffset.dx, 0),
        Offset(selectedOffset.dx, height),
        guidePaint,
      );

      final outerGlow = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 9, outerGlow);

      final dotPaint = Paint()
        ..color = isDark ? Colors.white : Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 5, dotPaint);

      final innerDot = Paint()
        ..color = isDark ? Colors.black : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedOffset, 2.5, innerDot);
    }
  }

  @override
  bool shouldRepaint(covariant _RepoStarChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.points != points ||
        oldDelegate.isDark != isDark;
  }
}
