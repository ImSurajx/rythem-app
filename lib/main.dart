import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database.dart';
import 'core/ingestion/ingestion.dart';
import 'core/pacing/pacing.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
import 'core/widgets/widgets.dart';
import 'features/flow/flow_screen.dart';
import 'features/explore/explore_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RythemApp());
}

class RythemApp extends StatefulWidget {
  const RythemApp({super.key});

  @override
  State<RythemApp> createState() => _RythemAppState();
}

class _RythemAppState extends State<RythemApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rythem',
      debugShowCheckedModeBanner: false,
      theme: RythemTheme.lightTheme,
      darkTheme: RythemTheme.darkTheme,
      themeMode: _themeMode,
      home: DesignSystemShowcaseScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class DesignSystemShowcaseScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const DesignSystemShowcaseScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<DesignSystemShowcaseScreen> createState() =>
      _DesignSystemShowcaseScreenState();
}

class _DesignSystemShowcaseScreenState
    extends State<DesignSystemShowcaseScreen> {
  final _roadmapRepo = RoadmapRepository();
  final _chapterRepo = ChapterRepository();
  final _beatRepo = BeatRepository();
  final _beatLogRepo = BeatLogRepository();
  late final _ingestionService = CurriculumIngestionService(
    roadmapRepo: _roadmapRepo,
    chapterRepo: _chapterRepo,
    beatRepo: _beatRepo,
  );
  late final _pacingService = PacingService(
    roadmapRepo: _roadmapRepo,
    beatRepo: _beatRepo,
    beatLogRepo: _beatLogRepo,
  );

  StreamSubscription<DatabaseEvent>? _eventSubscription;

  String _roadmapTitle = 'Deep Learning & Neural Flow';
  String _roadmapId = 'rm_demo';
  int _currentStreak = 1;
  List<ChapterEntity> _chapters = [];
  List<BeatEntity> _beats = [];
  Map<String, List<ChapterEntity>> _chaptersByRoadmap = {};
  Map<String, List<BeatEntity>> _beatsByRoadmap = {};
  Map<String, PacingBudget> _budgetsByRoadmap = {};
  List<RoadmapEntity> _allRoadmaps = [];

  PacingBudget? _pacingBudget;
  DateTime? _simulatedNow;
  int _currentTabIndex = 0;
  String _pacingCalibration = 'normal';

  Future<void> _setBeatCompletion(BeatEntity beat, bool isCompleted) async {
    await _beatRepo.toggleBeatCompletion(beat.id, isCompleted: isCompleted);
    await _loadDatabaseState();
  }

  @override
  void initState() {
    super.initState();
    _eventSubscription = DatabaseEventBus.instance.stream.listen((event) {
      _loadDatabaseState();
    });
    _initDatabaseAndSeed();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDatabaseAndSeed() async {
    try {
      final active = await _roadmapRepo.getActiveRoadmaps();
      if (active.isEmpty) {
        await _seedSampleData();
      } else {
        _roadmapId = active.first.id;
        _roadmapTitle = active.first.title;
      }
      await _loadDatabaseState();
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  Future<void> _seedSampleData() async {
    final now = DateTime.now();
    _roadmapId = 'rm_demo';
    _roadmapTitle = 'Deep Learning & Neural Flow';

    await _roadmapRepo.createRoadmap(RoadmapEntity(
      id: _roadmapId,
      title: _roadmapTitle,
      description: 'Mastering backpropagation, loss surfaces, and attention dynamics.',
      targetCompletionDate: now.add(const Duration(days: 14)),
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
    ));

    await _chapterRepo.createChapter(ChapterEntity(
      id: 'ch_foundations',
      roadmapId: _roadmapId,
      title: 'Chapter 1: Mathematical Foundations',
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    ));

    final sampleBeats = [
      BeatEntity(
        id: 'beat_1',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Calculus & Gradient Vectors',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: true,
        completedAt: now.subtract(const Duration(hours: 3)),
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_2',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Forward & Backpropagation',
        effortWeight: 1.5,
        sortOrder: 1,
        isCompleted: true,
        completedAt: now.subtract(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_3',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Activation Functions & Loss Surfaces',
        effortWeight: 1.0,
        sortOrder: 2,
        isCompleted: true,
        completedAt: now.subtract(const Duration(hours: 1)),
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_4',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Weight Initialization Secrets',
        effortWeight: 1.8,
        sortOrder: 3,
        isCompleted: false,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_5',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Batch Normalization Dynamics',
        effortWeight: 1.2,
        sortOrder: 4,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_6',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Residual Connections & ResNet',
        effortWeight: 1.6,
        sortOrder: 5,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      BeatEntity(
        id: 'beat_7',
        chapterId: 'ch_foundations',
        roadmapId: _roadmapId,
        title: 'Self-Attention Mechanism',
        effortWeight: 2.0,
        sortOrder: 6,
        isCompleted: false,
        isMentorExtra: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await _beatRepo.createBeatsBatch(sampleBeats);
  }

  Future<void> _loadDatabaseState() async {
    final allRoadmaps = await _roadmapRepo.getActiveRoadmaps();
    if (allRoadmaps.isEmpty) {
      if (mounted) {
        setState(() {
          _allRoadmaps = [];
          _roadmapId = '';
          _roadmapTitle = 'No Active Target';
          _chapters = [];
          _beats = [];
          _pacingBudget = null;
        });
      }
      return;
    }

    if (_roadmapId.isEmpty || !allRoadmaps.any((r) => r.id == _roadmapId)) {
      _roadmapId = allRoadmaps.first.id;
      _roadmapTitle = allRoadmaps.first.title;
    } else {
      final cur = allRoadmaps.firstWhere((r) => r.id == _roadmapId);
      _roadmapTitle = cur.title;
    }

    // Fetch chapters, beats, and budgets for ALL roadmaps
    final chaptersByRoadmap = <String, List<ChapterEntity>>{};
    final beatsByRoadmap = <String, List<BeatEntity>>{};
    final budgetsByRoadmap = <String, PacingBudget>{};

    for (final rm in allRoadmaps) {
      final chs = await _chapterRepo.getChaptersByRoadmapId(rm.id);
      final bts = await _beatRepo.getBeatsByRoadmapId(rm.id);
      chaptersByRoadmap[rm.id] = chs;
      beatsByRoadmap[rm.id] = bts;

      try {
        final b = await _pacingService.computePacingBudget(
          rm.id,
          simulatedNow: _simulatedNow,
        );
        budgetsByRoadmap[rm.id] = b;
      } catch (e) {
        debugPrint('Notice: Pacing budget for ${rm.id}: $e');
      }
    }

    final chapters = chaptersByRoadmap[_roadmapId] ?? [];
    final beats = beatsByRoadmap[_roadmapId] ?? [];
    final streak = await _beatLogRepo.getCurrentStreak();

    // Group beats by their chapter
    final beatsByChapter = <String, List<BeatEntity>>{};
    for (final ch in chapters) {
      beatsByChapter[ch.id] = [];
    }
    for (final b in beats) {
      if (!beatsByChapter.containsKey(b.chapterId)) {
        beatsByChapter[b.chapterId] = [];
      }
      beatsByChapter[b.chapterId]!.add(b);
    }

    final budget = budgetsByRoadmap[_roadmapId];

    if (mounted) {
      setState(() {
        _allRoadmaps = allRoadmaps;
        _chapters = chapters;
        _beats = beats;
        _chaptersByRoadmap = chaptersByRoadmap;
        _beatsByRoadmap = beatsByRoadmap;
        _budgetsByRoadmap = budgetsByRoadmap;
        _currentStreak = streak > 0 ? streak : 1;
        _pacingBudget = budget;
      });
    }
  }

  Future<void> _advanceNextBeat() async {
    final pending = await _beatRepo.getPendingBeats(_roadmapId);
    if (pending.isNotEmpty) {
      final nextBeat = pending.first;
      await _beatRepo.toggleBeatCompletion(nextBeat.id, isCompleted: true);
    } else {
      // Loop over: reset all beats to uncompleted
      for (final b in _beats) {
        await _beatRepo.toggleBeatCompletion(b.id, isCompleted: false);
      }
    }
    await _loadDatabaseState();
  }

  Future<void> _resetAndReseedDatabase() async {
    await _roadmapRepo.deleteRoadmap(_roadmapId);
    _simulatedNow = null;
    await _seedSampleData();
    await _loadDatabaseState();
    HapticFeedback.mediumImpact();
    _showToast('Reset database to demo starter track');
  }

  void _switchRoadmap(RoadmapEntity rm) {
    setState(() {
      _roadmapId = rm.id;
      _roadmapTitle = rm.title;
      _simulatedNow = null;
    });
    _loadDatabaseState();
    HapticFeedback.selectionClick();
  }

  // --- Pacing Engine Simulation Handlers ---

  Future<void> _simulateMissedDay() async {
    _simulatedNow = (_simulatedNow ?? DateTime.now()).add(const Duration(days: 1));
    await _loadDatabaseState();
    HapticFeedback.mediumImpact();
    final remainingDays = _pacingBudget?.daysLeft ?? 0;
    final newBudget = _pacingBudget?.formattedBudget ?? "0.0";
    _showToast('Simulated +1 Day Missed: Backlog diluted across $remainingDays days ($newBudget effort/day)');
  }

  Future<void> _completeTodaysQuota() async {
    if (_pacingBudget != null && _pacingBudget!.todaysBeats.isNotEmpty) {
      for (final b in _pacingBudget!.todaysBeats) {
        await _beatRepo.toggleBeatCompletion(b.id, isCompleted: true);
      }
      await _loadDatabaseState();
      HapticFeedback.mediumImpact();
      _showToast("✓ Completed today's mission! Tomorrow's budget recalculated.");
    } else {
      _showToast('No pending beats assigned for today.');
    }
  }

  Future<void> _simulate3DayLag() async {
    _simulatedNow = (_simulatedNow ?? DateTime.now()).add(const Duration(days: 3));
    await _loadDatabaseState();
    HapticFeedback.heavyImpact();
    _showAdaptivePacingModal();
  }

  Future<void> _resetSimulationClock() async {
    _simulatedNow = null;
    await _loadDatabaseState();
    HapticFeedback.lightImpact();
    _showToast('Simulation clock reset to current time.');
  }

  void _showAdaptivePacingModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final themeColors = RythemColors.of(context);
        final isDark = themeColors.isDark;

        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ADAPTIVE PACING DECISION',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: themeColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sustained lag detected (3+ days). Pure-math adaptation offers 4 non-punitive options to recover rhythm without shame.',
                style: RythemTypography.bodyMedium.copyWith(
                  color: themeColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              _adaptiveOptionCard(
                title: 'Push Target Date (+7 Days)',
                description: 'Extends completion date smoothly diluting remaining effort across more days.',
                icon: Icons.calendar_today_outlined,
                onTap: () async {
                  Navigator.pop(context);
                  await _pacingService.applyPacingDecision(
                    _roadmapId,
                    const PacingDecision.extendDate(7),
                  );
                  await _loadDatabaseState();
                  _showToast('Target completion date extended by 7 days.');
                },
                themeColors: themeColors,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _adaptiveOptionCard(
                title: 'Trim to Core Must-Do Beats',
                description: 'Focus effort on foundational beats while keeping extras tagged in place.',
                icon: Icons.filter_list_outlined,
                onTap: () async {
                  Navigator.pop(context);
                  await _pacingService.applyPacingDecision(
                    _roadmapId,
                    const PacingDecision.trimCore(),
                  );
                  await _loadDatabaseState();
                  _showToast('Focus trimmed to core curriculum beats.');
                },
                themeColors: themeColors,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _adaptiveOptionCard(
                title: 'Borrow Slack from Other Tracks',
                description: 'Rebalance daily effort from tracks that are currently ahead of pace.',
                icon: Icons.swap_calls_outlined,
                onTap: () async {
                  Navigator.pop(context);
                  await _pacingService.applyPacingDecision(
                    _roadmapId,
                    const PacingDecision.borrow('secondary'),
                  );
                  await _loadDatabaseState();
                  _showToast('Slack borrowed from secondary tracks.');
                },
                themeColors: themeColors,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _adaptiveOptionCard(
                title: 'Accept & Continue',
                description: 'Keep existing dates and absorb pace naturally across remaining timeline.',
                icon: Icons.check_circle_outline,
                onTap: () async {
                  Navigator.pop(context);
                  await _pacingService.applyPacingDecision(
                    _roadmapId,
                    const PacingDecision.accept(),
                  );
                  await _loadDatabaseState();
                  _showToast('Accepted current pace.');
                },
                themeColors: themeColors,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _adaptiveOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required RythemThemeColors themeColors,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? themeColors.glassBorder : const Color(0x14000000),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: themeColors.textPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RythemTypography.titleMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: themeColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: RythemTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: themeColors.textSecondary,
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

  void _showRoadmapSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeColors = RythemColors.of(context);
        final isDark = themeColors.isDark;

        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STORED TARGET TRACKS IN SQLITE',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: themeColors.textSecondary, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_allRoadmaps.isEmpty)
                Text(
                  'No targets found in SQLite database.',
                  style: TextStyle(color: themeColors.textSecondary),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _allRoadmaps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final rm = _allRoadmaps[i];
                      final isCurrent = rm.id == _roadmapId;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _switchRoadmap(rm);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08))
                                : (isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.black.withOpacity(0.02)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? themeColors.glassBorderHighlight
                                  : (isDark
                                      ? themeColors.glassBorder
                                      : const Color(0x14000000)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCurrent
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isCurrent
                                    ? themeColors.textPrimary
                                    : themeColors.textTertiary,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  rm.title,
                                  style: RythemTypography.bodyLarge.copyWith(
                                    color: themeColors.textPrimary,
                                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return Scaffold(
      backgroundColor: themeColors.background,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar with Brand Logo & Theme Mode Toggle (always accessible)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RYTHEM',
                            style: RythemTypography.brandLogo.copyWith(
                              color: themeColors.textPrimary,
                              letterSpacing: 3.5,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'beats over clocks • felt, not measured',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Dark / Light Glass Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onToggleTheme();
                    },
                    child: GlassContainer(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(20),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: themeColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Persistent 4-Tab Indexed Stack
            Expanded(
              child: IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildFlowTab(),
                  _buildExploreTab(themeColors, isDark),
                  _buildMetricsTab(themeColors, isDark),
                  _buildSettingsTab(themeColors, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GlassBottomDock(
        selectedIndex: _currentTabIndex,
        onItemSelected: (idx) {
          setState(() => _currentTabIndex = idx);
        },
      ),
    );
  }

  Widget _buildFlowTab() {
    final activeRoadmap =
        _allRoadmaps.where((r) => r.id == _roadmapId).firstOrNull;
    return FlowScreen(
      activeRoadmap: activeRoadmap,
      allRoadmaps: _allRoadmaps,
      chapters: _chapters,
      allBeats: _beats,
      pacingBudget: _pacingBudget,
      chaptersByRoadmap: _chaptersByRoadmap,
      beatsByRoadmap: _beatsByRoadmap,
      budgetsByRoadmap: _budgetsByRoadmap,
      streakDays: _currentStreak,
      onSwitchRoadmap: _showRoadmapSelector,
      onBeatToggled: _setBeatCompletion,
      onExploreTracks: () => setState(() => _currentTabIndex = 1),
    );
  }

  Future<void> _handleCreateTrack({
    required String title,
    required String category,
    required DateTime targetDate,
    String? resourceUrl,
  }) async {
    if (resourceUrl != null && resourceUrl.isNotEmpty) {
      await _ingestionService.ingestFromUrl(
        url: resourceUrl,
        customRoadmapTitle: title,
        customDescription: category,
        targetCompletionDate: targetDate,
      );
    } else {
      final id = 'rm_${DateTime.now().millisecondsSinceEpoch}';
      final rm = RoadmapEntity(
        id: id,
        title: title,
        description: category,
        targetCompletionDate: targetDate,
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _roadmapRepo.createRoadmap(rm);
      final ch = ChapterEntity(
        id: 'ch_${id}_1',
        roadmapId: id,
        title: 'Core Foundations',
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _chapterRepo.createChapter(ch);
      final beat = BeatEntity(
        id: 'beat_${id}_1',
        chapterId: ch.id,
        roadmapId: id,
        title: 'Initial Orientation',
        effortWeight: 1.0,
        sortOrder: 0,
        isCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _beatRepo.createBeat(beat);
    }
    await _loadDatabaseState();
  }

  Future<void> _handleArchiveRoadmap(RoadmapEntity roadmap) async {
    final updated = roadmap.copyWith(status: 'archived', updatedAt: DateTime.now());
    await _roadmapRepo.updateRoadmap(updated);
    await _loadDatabaseState();
  }

  Future<void> _handleRestoreRoadmap(RoadmapEntity roadmap) async {
    final updated = roadmap.copyWith(status: 'active', updatedAt: DateTime.now());
    await _roadmapRepo.updateRoadmap(updated);
    await _loadDatabaseState();
  }

  Future<void> _handleAttachResource(String roadmapId, String resourceUrl) async {
    try {
      final rm = _allRoadmaps.where((r) => r.id == roadmapId).firstOrNull;
      await _ingestionService.ingestFromUrl(
        url: resourceUrl,
        customRoadmapTitle: rm?.title,
        customDescription: rm?.description,
      );
      await _loadDatabaseState();
    } catch (e) {
      debugPrint('Error attaching resource: $e');
    }
  }

  Widget _buildExploreTab(RythemThemeColors themeColors, bool isDark) {
    return ExploreScreen(
      roadmaps: _allRoadmaps,
      chaptersByRoadmap: _chaptersByRoadmap,
      beatsByRoadmap: _beatsByRoadmap,
      onBeatToggled: _setBeatCompletion,
      onCreateTrack: _handleCreateTrack,
      onArchiveRoadmap: _handleArchiveRoadmap,
      onRestoreRoadmap: _handleRestoreRoadmap,
      onAttachResource: _handleAttachResource,
    );
  }

  Widget _buildMetricsTab(RythemThemeColors themeColors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PACING ENGINE (PURE MATH • ZERO STOPWATCHES)',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_outlined, size: 16, color: themeColors.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'DAILY EFFORT ALLOCATION',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    if (_simulatedNow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorderHighlight : const Color(0x20000000),
                          ),
                        ),
                        child: Text(
                          'SIMULATED: ${_simulatedNow!.month}/${_simulatedNow!.day}',
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3 Stat metrics
                Row(
                  children: [
                    Expanded(
                      child: _pacingMetricTile(
                        title: "TODAY'S BUDGET",
                        value: '${_pacingBudget?.formattedBudget ?? "0.0"} effort',
                        subtitle: 'remaining ÷ days',
                        themeColors: themeColors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _pacingMetricTile(
                        title: 'DAYS LEFT',
                        value: '${_pacingBudget?.daysLeft ?? 0} days',
                        subtitle: 'calendar window',
                        themeColors: themeColors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _pacingMetricTile(
                        title: 'PENDING EFFORT',
                        value: _pacingBudget?.remainingEffort.toStringAsFixed(1) ?? '0.0',
                        subtitle: 'uncompleted sum',
                        themeColors: themeColors,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Pacing Status Banner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_pacingBudget?.isRoadmapCompleted ?? false)
                                ? const Color(0xFF34C759)
                                : (_pacingBudget?.isDailyQuotaCompleted ?? false)
                                    ? const Color(0xFF34C759)
                                    : (_pacingBudget?.isSustainedLag ?? false)
                                        ? const Color(0xFFFF9500)
                                        : themeColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          (_pacingBudget?.isRoadmapCompleted ?? false)
                              ? 'TRACK COMPLETED'
                              : (_pacingBudget?.isDailyQuotaCompleted ?? false)
                                  ? "TODAY'S QUOTA COMPLETE"
                                  : (_pacingBudget?.isSustainedLag ?? false)
                                      ? 'SUSTAINED LAG (${_pacingBudget!.lagStreakDays} DAYS)'
                                      : "TODAY'S MISSION: ${_pacingBudget?.todaysBeats.length ?? 0} BEATS ASSIGNED",
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'felt, not measured',
                      style: RythemTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: themeColors.textTertiary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Interactive Math Simulation Controls
                Text(
                  'ON-DEVICE PACING MATH SIMULATORS',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _testPresetChip(
                      label: '+1 Missed Day (Dilution)',
                      onTap: _simulateMissedDay,
                    ),
                    _testPresetChip(
                      label: "Complete Today's Mission",
                      onTap: _completeTodaysQuota,
                    ),
                    _testPresetChip(
                      label: 'Simulate 3-Day Lag (Adaptation)',
                      onTap: _simulate3DayLag,
                    ),
                    if (_simulatedNow != null)
                      _testPresetChip(
                        label: 'Reset Clock',
                        onTap: _resetSimulationClock,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab(RythemThemeColors themeColors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS & CALIBRATION',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Pacing Calibration Card (design.md §0 Step 4 & §5)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune_outlined, size: 18, color: themeColors.textPrimary),
                    const SizedBox(width: 10),
                    Text(
                      'PACING CALIBRATION',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Controls your daily effort budget rate. Zero minutes, hours, or stopwatch times shown.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                _buildCalibrationOption(
                  'light',
                  'Light',
                  'Gentle effort quota. Best for busy weeks or secondary study tracks.',
                  themeColors,
                  isDark,
                ),
                _buildCalibrationOption(
                  'normal',
                  'Normal',
                  'Balanced mentor-paced queue flow. Recommended standard.',
                  themeColors,
                  isDark,
                ),
                _buildCalibrationOption(
                  'intense',
                  'Intense',
                  'Accelerated budget allocation for focused immersion sprints.',
                  themeColors,
                  isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Local Database & Architecture Status
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 18, color: themeColors.textPrimary),
                    const SizedBox(width: 10),
                    Text(
                      'LOCAL-FIRST PERSISTENCE',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Database: SQLite [rythem.db]\nReactive Stream: Active\nNetwork Dependency: Zero for offline learning',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Advance Beat',
                        variant: GlassButtonVariant.secondary,
                        onPressed: _advanceNextBeat,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassButton(
                        label: 'Reseed DB',
                        variant: GlassButtonVariant.secondary,
                        onPressed: _resetAndReseedDatabase,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // App Philosophy Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RYTHEM PHILOSOPHY',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Beats over clocks. Felt, not measured. Learning happens in sequence, not in arbitrary stopwatch sessions.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Rythem v1.0.0 • Pure Math Pacing • Local First',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationOption(
    String option,
    String label,
    String description,
    RythemThemeColors themeColors,
    bool isDark,
  ) {
    final isSelected = _pacingCalibration == option;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _pacingCalibration = option);
        _showToast('Pacing calibration updated to $label');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08))
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? themeColors.glassBorderHighlight : Colors.black87)
                : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: RythemTypography.titleSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 10.5,
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

  Widget _pacingMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required RythemThemeColors themeColors,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x10000000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: RythemTypography.titleMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: RythemTypography.labelSmall.copyWith(
              fontSize: 8.5,
              color: themeColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }


  Widget _testPresetChip({
    required String label,
    VoidCallback? onTap,
  }) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (onTap != null) {
          onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? themeColors.glassBorder : const Color(0x14000000),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flash_on_outlined,
              size: 13,
              color: themeColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: RythemTypography.labelSmall.copyWith(
                color: themeColors.textPrimary,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
