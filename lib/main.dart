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

  final _urlInputController = TextEditingController();
  StreamSubscription<DatabaseEvent>? _eventSubscription;

  String _roadmapTitle = 'Deep Learning & Neural Flow';
  String _roadmapId = 'rm_demo';
  int _completedBeats = 3;
  int _totalBeats = 7;
  double _progressRatio = 3 / 7;
  int _currentStreak = 1;
  List<ChapterEntity> _chapters = [];
  List<BeatEntity> _beats = [];
  Map<String, List<BeatEntity>> _beatsByChapter = {};
  List<RoadmapEntity> _allRoadmaps = [];
  bool _isIngesting = false;
  String? _lastIngestionSummary;

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
    _urlInputController.dispose();
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
          _beatsByChapter = {};
          _completedBeats = 0;
          _totalBeats = 0;
          _progressRatio = 0.0;
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

    final chapters = await _chapterRepo.getChaptersByRoadmapId(_roadmapId);
    final beats = await _beatRepo.getBeatsByRoadmapId(_roadmapId);
    final progress = await _roadmapRepo.getRoadmapProgress(_roadmapId);
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

    // Compute live deterministic pacing budget
    PacingBudget? budget;
    try {
      budget = await _pacingService.computePacingBudget(
        _roadmapId,
        simulatedNow: _simulatedNow,
      );
    } catch (e) {
      debugPrint('Notice: Pacing budget calculation: $e');
    }

    if (mounted) {
      setState(() {
        _allRoadmaps = allRoadmaps;
        _chapters = chapters;
        _beats = beats;
        _beatsByChapter = beatsByChapter;
        _completedBeats = progress.completedBeats;
        _totalBeats = progress.totalBeats > 0 ? progress.totalBeats : beats.length;
        _progressRatio = _totalBeats > 0 ? (_completedBeats / _totalBeats) : 0.0;
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

  Future<void> _toggleBeat(BeatEntity beat) async {
    await _beatRepo.toggleBeatCompletion(beat.id, isCompleted: !beat.isCompleted);
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

  Future<void> _deleteCurrentRoadmap() async {
    if (_roadmapId.isEmpty) return;
    await _roadmapRepo.deleteRoadmap(_roadmapId);
    final remaining = await _roadmapRepo.getActiveRoadmaps();
    if (remaining.isNotEmpty) {
      _roadmapId = remaining.first.id;
      _roadmapTitle = remaining.first.title;
    } else {
      _roadmapId = '';
      _roadmapTitle = 'No Active Target';
    }
    _simulatedNow = null;
    await _loadDatabaseState();
    HapticFeedback.mediumImpact();
    _showToast('Target deleted from SQLite');
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

  // --- Ingestion Live URL Processing ---

  /// Test Condition 1: Blank Roadmap + YouTube Playlist (Zero-Drop Guarantee & Chapter Clustering)
  Future<void> _testCondition1() async {
    setState(() => _isIngesting = true);
    HapticFeedback.lightImpact();

    try {
      final items = List.generate(
        16,
        (i) => RawResourceItem(
          title: 'Lesson ${i + 1}: Modern Neural Systems Part ${i + 1}',
          sourceUrl: 'https://youtube.com/watch?v=mock_$i',
          durationSeconds: 720 + (i * 45),
          index: i,
        ),
      );

      final resource = ExtractedResource(
        title: 'Neural Networks Masterclass (Condition 1)',
        author: 'AI Research Mentor',
        description: 'Condition 1 Test: 16 flat videos clustered with zero drop.',
        sourceUrl: 'https://youtube.com/playlist?list=PL_c1_demo',
        resourceType: ExtractedResourceType.playlist,
        items: items,
      );

      final result = await _ingestionService.ingestExtractedResource(
        extracted: resource,
      );

      _roadmapId = result.roadmapId;
      _roadmapTitle = result.roadmapTitle;
      _simulatedNow = null;
      _lastIngestionSummary =
          'Condition 1: Ingested ${result.beatsCount} beats into ${result.chaptersCount} chapters (100% zero drop)!';

      await _loadDatabaseState();
      _showToast(_lastIngestionSummary!);
    } catch (e) {
      _showToast('Condition 1 Error: $e');
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
  }

  /// Test Condition 2: Existing Syllabus Outline + Mentor Playlist (Mentor Flow & Extras Tagging)
  Future<void> _testCondition2() async {
    setState(() => _isIngesting = true);
    HapticFeedback.lightImpact();

    try {
      final items = [
        const RawResourceItem(
          title: 'Matrix Operations & Linear Algebra Foundations',
          sourceUrl: 'https://youtube.com/watch?v=m1',
          durationSeconds: 900,
          index: 0,
        ),
        const RawResourceItem(
          title: 'Calculus, Gradients & Automatic Differentiation',
          sourceUrl: 'https://youtube.com/watch?v=m2',
          durationSeconds: 1200,
          index: 1,
        ),
        const RawResourceItem(
          title: 'Mentor Special: Vim & NeoVim Mastery for AI Engineers',
          sourceUrl: 'https://youtube.com/watch?v=m3',
          durationSeconds: 1500,
          index: 2,
        ),
        const RawResourceItem(
          title: 'Convolutional Neural Networks & Feature Maps',
          sourceUrl: 'https://youtube.com/watch?v=m4',
          durationSeconds: 1100,
          index: 3,
        ),
        const RawResourceItem(
          title: 'Mentor Special: Profiling PyTorch CUDA Memory Spikes',
          sourceUrl: 'https://youtube.com/watch?v=m5',
          durationSeconds: 1400,
          index: 4,
        ),
        const RawResourceItem(
          title: 'Transformer Architecture & Self-Attention Mechanics',
          sourceUrl: 'https://youtube.com/watch?v=m6',
          durationSeconds: 1800,
          index: 5,
        ),
      ];

      final resource = ExtractedResource(
        title: 'Deep Learning with Syllabus (Condition 2)',
        author: 'Mentor Lab',
        description: 'Condition 2 Test: Aligns syllabus and flags mentor extras in place.',
        sourceUrl: 'https://youtube.com/playlist?list=PL_c2_demo',
        resourceType: ExtractedResourceType.playlist,
        items: items,
      );

      final syllabus = [
        const SyllabusTopic(id: 's_linalg', title: 'Linear Algebra and Matrix Theory'),
        const SyllabusTopic(id: 's_calc', title: 'Calculus and Automatic Differentiation'),
        const SyllabusTopic(id: 's_cnn', title: 'Convolutional Neural Networks (CNNs)'),
        const SyllabusTopic(id: 's_transformer', title: 'Self-Attention and Transformer Models'),
      ];

      final result = await _ingestionService.ingestExtractedResource(
        extracted: resource,
        syllabus: syllabus,
      );

      _roadmapId = result.roadmapId;
      _roadmapTitle = result.roadmapTitle;
      _simulatedNow = null;
      _lastIngestionSummary =
          'Condition 2: Aligned syllabus. ${result.mentorExtraCount} mentor extras tagged in place!';

      await _loadDatabaseState();
      _showToast(_lastIngestionSummary!);
    } catch (e) {
      _showToast('Condition 2 Error: $e');
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
  }

  /// Ingest real custom YouTube URL (Playlist or Single Video with Chapter Timestamps)
  Future<void> _ingestCustomUrl(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) {
      _showToast('Please paste a valid YouTube URL');
      return;
    }

    setState(() => _isIngesting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _ingestionService.ingestFromUrl(url: clean);
      _roadmapId = result.roadmapId;
      _roadmapTitle = result.roadmapTitle;
      _simulatedNow = null;
      _lastIngestionSummary =
          '✓ Ingested ${result.beatsCount} videos into ${result.chaptersCount} chapters in SQLite!';
      _urlInputController.clear();
      await _loadDatabaseState();
      _showToast(_lastIngestionSummary!);
    } catch (e) {
      _showToast('Ingestion Error: $e');
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
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

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '10m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    } else {
      return '${s}s';
    }
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
      streakDays: _currentStreak,
      onSwitchRoadmap: _showRoadmapSelector,
      onBeatToggled: _setBeatCompletion,
      onExploreTracks: () => setState(() => _currentTabIndex = 1),
    );
  }

  Widget _buildExploreTab(RythemThemeColors themeColors, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Database Connection Badge & Switch Track Pill
          Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF34C759),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SQLITE READY • PACING ENGINE ACTIVE',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  if (_allRoadmaps.length > 1)
                    GestureDetector(
                      onTap: _showRoadmapSelector,
                      child: Container(
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
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, size: 14, color: themeColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              'Switch Track (${_allRoadmaps.length})',
                              style: RythemTypography.labelSmall.copyWith(
                                fontSize: 10,
                                color: themeColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Theme Spec Section
              Text(
                isDark
                    ? 'MONOCHROME LIQUID GLASS (DARK)'
                    : 'APPLE CONTROL CENTER GLASS (LIGHT)',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              // Hero Glass Card (Active Target Status & Progress)
              GlassCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _roadmapTitle,
                                style: RythemTypography.titleLarge.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _roadmapId == 'rm_demo'
                                    ? 'Starter Target • Tap beats below to test SQLite updates'
                                    : 'Active Target • ${_chapters.length} chapters • ${_beats.length} beats',
                                style: RythemTypography.bodyMedium.copyWith(
                                  color: themeColors.textTertiary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? themeColors.glassBorder
                                  : const Color(0x14000000),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isDark ? 'DARK GLASS' : 'LIGHT GLASS',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Milestone Progress Bar (No time, pure ratio)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_completedBeats of $_totalBeats beats completed',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${(_progressRatio * 100).toInt()}%',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GlassProgressBar(
                      progress: _progressRatio,
                      height: 8,
                    ),

                    const SizedBox(height: 16),

                    // Flow Streak Metrics (Felt, Not Clock-Measured) & Today's Budget Pill
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? themeColors.glassBorder
                                  : const Color(0x14000000),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.offline_bolt_outlined,
                                size: 14,
                                color: themeColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Flow Streak: $_currentStreak Day${_currentStreak == 1 ? '' : 's'}',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? themeColors.glassBorder
                                  : const Color(0x14000000),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_outlined,
                                size: 13,
                                color: themeColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Today's Budget: ${_pacingBudget?.formattedBudget ?? '0.0'} effort",
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_allRoadmaps.length > 1)
                          GestureDetector(
                            onTap: _deleteCurrentRoadmap,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.delete_outline, size: 14, color: themeColors.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  'Delete Target',
                                  style: RythemTypography.labelSmall.copyWith(
                                    color: themeColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            'zero stopwatches',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Dedicated Live YouTube Ingestion Form
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'INGEST YOUTUBE CURRICULUM',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_isIngesting)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Paste any YouTube Playlist or video with chapter timestamps.',
                      style: RythemTypography.bodyMedium.copyWith(
                        color: themeColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlInputController,
                            style: RythemTypography.bodyLarge.copyWith(
                              color: themeColors.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'https://youtube.com/playlist?list=...',
                              hintStyle: TextStyle(
                                color: themeColors.textTertiary,
                                fontSize: 12,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? themeColors.glassBorder
                                      : const Color(0x14000000),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: themeColors.textPrimary,
                                  width: 1.2,
                                ),
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Paste from clipboard',
                                icon: Icon(
                                  Icons.content_paste_outlined,
                                  size: 18,
                                  color: themeColors.textSecondary,
                                ),
                                onPressed: () async {
                                  final data = await Clipboard.getData('text/plain');
                                  if (data?.text != null && data!.text!.isNotEmpty) {
                                    _urlInputController.text = data.text!.trim();
                                    HapticFeedback.selectionClick();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassButton(
                          label: _isIngesting ? 'Ingesting...' : 'Ingest',
                          width: 90,
                          variant: GlassButtonVariant.primary,
                          onPressed: _isIngesting
                              ? null
                              : () {
                                  final url = _urlInputController.text.trim();
                                  if (url.isNotEmpty) {
                                    _ingestCustomUrl(url);
                                  } else {
                                    _showToast('Please paste a YouTube URL first');
                                  }
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QUICK 1-TAP TEST PRESETS',
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
                          label: 'Karpathy: 10-Video Playlist',
                          url: 'https://www.youtube.com/playlist?list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
                        ),
                        _testPresetChip(
                          label: 'Karpathy: GPT Chapters (Timestamps)',
                          url: 'https://www.youtube.com/watch?v=kCc8FmEb1nY',
                        ),
                        _testPresetChip(
                          label: 'Condition 1: Mock 16-Video 0-Drop',
                          onTap: _testCondition1,
                        ),
                        _testPresetChip(
                          label: 'Condition 2: Syllabus Matcher',
                          onTap: _testCondition2,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Active Chapter & Beats Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CURRICULUM TRACKER (${_beats.length} BEATS • ${_chapters.length} CHAPTERS)',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    'Tap beat to toggle',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Real SQLite Beats Grouped by Chapter
              if (_chapters.isEmpty && _beats.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.library_music_outlined, size: 36, color: themeColors.textTertiary),
                        const SizedBox(height: 10),
                        Text(
                          'No Target Track Loaded',
                          style: RythemTypography.titleMedium.copyWith(color: themeColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Paste a YouTube URL above or tap a preset to extract videos into SQLite.',
                          textAlign: TextAlign.center,
                          style: RythemTypography.bodyMedium.copyWith(
                            color: themeColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._chapters.map((chapter) {
                  final chapterBeats = _beatsByChapter[chapter.id] ?? [];
                  final completedInChapter = chapterBeats.where((b) => b.isCompleted).length;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chapter Header Pill
                        GlassContainer(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          borderRadius: BorderRadius.circular(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  chapter.title.toUpperCase(),
                                  style: RythemTypography.labelSmall.copyWith(
                                    color: themeColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$completedInChapter/${chapterBeats.length} beats',
                                  style: RythemTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: themeColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Beats in Chapter
                        ...chapterBeats.map((beat) => _buildBeatCard(beat, themeColors, isDark)),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),

              // Button Controls Section
              Text(
                'SQLITE MUTATION CONTROLS',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Advance Beat',
                      variant: GlassButtonVariant.primary,
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

              const SizedBox(height: 40),
            ],
          ),
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

  Widget _buildBeatCard(BeatEntity beat, RythemThemeColors themeColors, bool isDark) {
    final isCompleted = beat.isCompleted;
    final isAssignedToday = _pacingBudget != null &&
        _pacingBudget!.todaysBeats.any((b) => b.id == beat.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => _toggleBeat(beat),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? (isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.10))
                    : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
                border: Border.all(
                  color: isCompleted
                      ? (isDark ? themeColors.glassBorderHighlight : const Color(0x30000000))
                      : isAssignedToday
                          ? (isDark ? themeColors.glassBorderHighlight : const Color(0x30000000))
                          : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
                  width: isAssignedToday ? 1.5 : 1.2,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check : Icons.circle_outlined,
                color: isCompleted
                    ? themeColors.textPrimary
                    : isAssignedToday
                        ? themeColors.textPrimary
                        : themeColors.textTertiary,
                size: 16,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          beat.title,
                          style: RythemTypography.titleMedium.copyWith(
                            fontSize: 13,
                            color: isCompleted ? themeColors.textTertiary : themeColors.textPrimary,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isAssignedToday && !isCompleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? themeColors.glassBorderHighlight : const Color(0x25000000),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            "today's mission",
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (beat.isMentorExtra) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? themeColors.glassBorderHighlight : const Color(0x20000000),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'mentor extra',
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 9,
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '#${beat.sortOrder + 1}',
                        style: RythemTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: themeColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(fontSize: 10, color: themeColors.textTertiary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Effort ${beat.effortWeight}',
                        style: RythemTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: themeColors.textTertiary,
                        ),
                      ),
                      if (beat.timestampSeconds != null && beat.timestampSeconds! > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(fontSize: 10, color: themeColors.textTertiary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@${_formatDuration(beat.timestampSeconds!)}',
                          style: RythemTypography.labelSmall.copyWith(
                            fontSize: 10,
                            color: themeColors.textSecondary,
                          ),
                        ),
                      ],
                      if (beat.sourceUrl != null && beat.sourceUrl!.isNotEmpty) ...[
                        const Spacer(),
                        Icon(Icons.play_circle_outline, size: 14, color: themeColors.textTertiary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _testPresetChip({
    required String label,
    String? url,
    VoidCallback? onTap,
  }) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (url != null) {
          _urlInputController.text = url;
          _ingestCustomUrl(url);
        } else if (onTap != null) {
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
              url != null ? Icons.play_arrow_outlined : Icons.flash_on_outlined,
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
