import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/repositories/beat_log_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_card.dart';

enum GraphMode {
  monthly,
  lifetime,
}

/// Dual navigational performance graph card featuring:
/// 1. Monthly Performance (Daily velocity curve / bars)
/// 2. Lifetime Performance (Interactive Repo Star Growth curve with milestone stars and scrubber)
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
  GraphMode _mode = GraphMode.monthly;
  late final BeatLogRepository _repo;
  List<DailyBeatCount> _allLifetimeLogs = [];
  bool _isLoading = true;
  int? _scrubbedIndex;

  @override
  void initState() {
    super.initState();
    _repo = widget.beatLogRepo ?? BeatLogRepository();
    _loadLifetimeData();
  }

  Future<void> _loadLifetimeData() async {
    try {
      final logs = await _repo.getAllDailyActivity();
      if (mounted) {
        setState(() {
          _allLifetimeLogs = logs;
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
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Segmented Mode Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _mode == GraphMode.monthly ? Icons.insights_rounded : Icons.auto_graph_rounded,
                    size: 16,
                    color: widget.themeColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _mode == GraphMode.monthly ? 'MONTHLY PERFORMANCE' : 'LIFETIME STAR GROWTH',
                    style: RythemTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: widget.themeColors.textPrimary,
                    ),
                  ),
                ],
              ),
              // Segmented Toggle
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
            _mode == GraphMode.monthly
                ? 'Daily beat completions & pacing momentum across the active cycle'
                : 'Cumulative knowledge growth curve inspired by GitHub star trajectories',
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
          else if (_mode == GraphMode.monthly)
            _buildMonthlyPerformanceView()
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  // --- 1. Monthly Performance View ---
  Widget _buildMonthlyPerformanceView() {
    final activity = widget.recentActivity.isNotEmpty ? widget.recentActivity : <DailyBeatCount>[];
    int maxCount = 4;
    for (final day in activity) {
      if (day.count > maxCount) maxCount = day.count;
    }

    final totalBeats = activity.fold(0, (sum, d) => sum + d.count);
    final activeDays = activity.where((d) => d.count > 0).length;
    final avgPace = (totalBeats / math.max(1, activity.length)).toStringAsFixed(1);

    final selectedIndex = _scrubbedIndex != null && _scrubbedIndex! < activity.length
        ? _scrubbedIndex!
        : (activity.isNotEmpty ? activity.length - 1 : 0);
    final selectedDay = activity.isNotEmpty ? activity[selectedIndex] : null;

    return Column(
      children: [
        // Stats Highlight Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniMetric('TOTAL BEATS', '$totalBeats', widget.themeColors),
            _buildMiniMetric('AVG DAILY PACE', '$avgPace /d', widget.themeColors),
            _buildMiniMetric('ACTIVE DAYS', '$activeDays / ${activity.length}d', widget.themeColors),
          ],
        ),
        const SizedBox(height: 16),

        // Navigational Scrubbable Chart Area
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(activity.length, (idx) {
              final day = activity[idx];
              final isScrubbed = idx == selectedIndex;
              final ratio = (day.count / maxCount).clamp(0.0, 1.0);
              final barHeight = (ratio * 75).clamp(day.count > 0 ? 12.0 : 5.0, 75.0);

              DateTime? parsed;
              try {
                parsed = DateTime.parse(day.date);
              } catch (_) {}
              const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final dayLabel = parsed != null ? weekDays[parsed.weekday - 1] : '?';

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _scrubbedIndex = idx);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.count > 0)
                          Text(
                            '${day.count}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isScrubbed ? FontWeight.w800 : FontWeight.w600,
                              color: isScrubbed ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 4),
                        // Bar with Specular Accent
                        Container(
                          height: barHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: isScrubbed
                                ? (widget.isDark ? Colors.white : Colors.black)
                                : (day.count > 0
                                    ? (widget.isDark ? Colors.white38 : Colors.black38)
                                    : (widget.isDark ? Colors.white10 : Colors.black.withOpacity(0.06))),
                            border: isScrubbed
                                ? Border.all(
                                    color: widget.isDark ? Colors.white : Colors.black,
                                    width: 1.2,
                                  )
                                : null,
                            boxShadow: isScrubbed
                                ? [
                                    BoxShadow(
                                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: isScrubbed ? FontWeight.w700 : FontWeight.w500,
                            color: isScrubbed ? widget.themeColors.textPrimary : widget.themeColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Scrub Tooltip
        if (selectedDay != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDay.date,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.themeColors.textPrimary),
                ),
                Text(
                  '${selectedDay.count} beats completed',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.themeColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- 2. Lifetime Star Growth View (Repo Star Style) ---
  Widget _buildLifetimeStarGrowthView() {
    // Generate cumulative points
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
        // Star Summary Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniMetric('TOTAL STARS', '${cumulativePoints.last.cumulative} ⭐', widget.themeColors),
            _buildMiniMetric('TIMELINE DAYS', '${cumulativePoints.length}d', widget.themeColors),
            _buildMiniMetric('MILESTONES', '${(cumulativePoints.last.cumulative / 5).floor()} 🏆', widget.themeColors),
          ],
        ),
        const SizedBox(height: 18),

        // Custom Painted Growth Curve
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
            height: 130,
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

        // Scrubber Tooltip
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

    // Fill gradient underneath
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

    // Line stroke
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Scrub indicator
    if (selectedIndex >= 0 && selectedIndex < offsets.length) {
      final selectedOffset = offsets[selectedIndex];

      // Vertical guide line
      final guidePaint = Paint()
        ..color = (isDark ? Colors.white30 : Colors.black26)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(selectedOffset.dx, 0),
        Offset(selectedOffset.dx, height),
        guidePaint,
      );

      // Glowing scrub circle
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
