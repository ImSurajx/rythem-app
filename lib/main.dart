import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database.dart';
import 'core/ingestion/ingestion.dart';
import 'core/pacing/pacing.dart';
import 'core/ai/ai.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
import 'core/widgets/widgets.dart';
import 'core/ingestion/parsers/syllabus_parser.dart';
import 'features/flow/flow_screen.dart';
import 'features/explore/explore_screen.dart';
import 'features/explore/roadmap_detail_screen.dart';
import 'features/metrics/metrics_screen.dart';
import 'features/onboarding/onboarding_wizard_screen.dart';

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
  ThemeMode _themeMode = ThemeMode.system;
  final _settingsRepo = AppSettingsRepository();
  bool _isLoading = true;
  bool _hasCompletedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final val = await _settingsRepo.getSetting('has_completed_onboarding');
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = (val == 'true');
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = false;
          _isLoading = false;
        });
      }
    }
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (_isLoading) {
      home = const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    } else if (!_hasCompletedOnboarding) {
      home = OnboardingWizardScreen(
        onFinished: () {
          setState(() {
            _hasCompletedOnboarding = true;
          });
        },
      );
    } else {
      home = DesignSystemShowcaseScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      );
    }

    return MaterialApp(
      title: 'Rythem',
      debugShowCheckedModeBanner: false,
      theme: RythemTheme.lightTheme,
      darkTheme: RythemTheme.darkTheme,
      themeMode: _themeMode,
      home: home,
    );
  }
}

class DesignSystemShowcaseScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const DesignSystemShowcaseScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
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
  final _modelDownloadManager = ModelDownloadManager();
  late final _localInferenceService = LocalInferenceService(
    downloadManager: _modelDownloadManager,
    roadmapRepo: _roadmapRepo,
    beatRepo: _beatRepo,
    pacingService: _pacingService,
  );
  LocalInferenceService get inferenceService => _localInferenceService;

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
  List<DailyBeatCount> _recentActivity = [];

  PacingBudget? _pacingBudget;
  DateTime? _simulatedNow;
  int _currentTabIndex = 0;
  String _pacingCalibration = 'normal';

  ModelTier _activeModelTier = ModelTier.fallback;
  bool _compactDownloaded = false;
  bool _balancedDownloaded = false;

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
      description: 'Deep Learning',
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
    final recentActivity = await _beatLogRepo.getRecentActivity(daysCount: 7);

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
        _recentActivity = recentActivity;
        _pacingBudget = budget;
      });
    }
    await _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    try {
      final active = await _modelDownloadManager.getActiveTier();
      final compact = await _modelDownloadManager.isModelDownloaded(ModelTier.compact);
      final balanced = await _modelDownloadManager.isModelDownloaded(ModelTier.balanced);
      if (mounted) {
        setState(() {
          _activeModelTier = active;
          _compactDownloaded = compact;
          _balancedDownloaded = balanced;
        });
      }
    } catch (e) {
      debugPrint('Notice: Error loading model status: $e');
    }
  }

  Future<void> _handleDownloadModel(ModelTier tier) async {
    HapticFeedback.mediumImpact();
    _showToast('Downloading ${ModelInfo.forTier(tier).displayName} from GitHub Release...');
    try {
      await _modelDownloadManager.downloadModel(tier);
      await _loadModelStatus();
      _showToast('${ModelInfo.forTier(tier).displayName} ready & activated!');
    } catch (e) {
      if (mounted) {
        _showToast('Download interrupted: $e');
      }
      await _loadModelStatus();
    }
  }

  Future<void> _handleDeleteModel(ModelTier tier) async {
    HapticFeedback.lightImpact();
    await _modelDownloadManager.deleteModel(tier);
    await _loadModelStatus();
    _showToast('Removed ${ModelInfo.forTier(tier).displayName} from device storage');
  }

  Future<void> _handleSelectActiveModel(ModelTier tier) async {
    HapticFeedback.selectionClick();
    await _modelDownloadManager.setActiveTier(tier);
    await _loadModelStatus();
    _showToast('Active engine: ${ModelInfo.forTier(tier).displayName}');
  }

  void _showAiMentorTestModal() {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final topicController = TextEditingController(text: 'Binary Search & Edge Cases');
    bool isInferring = false;
    String? outputText;
    int? latencyMs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16191D) : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20, color: themeColors.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'TEST AI MENTOR INFERENCE',
                              style: RythemTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: themeColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _activeModelTier.name.toUpperCase(),
                            style: RythemTypography.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: themeColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Test your active on-device intelligence engine on any concept or beat topic.',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: topicController,
                      style: RythemTypography.bodyMedium.copyWith(color: themeColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Concept / Beat Title',
                        labelStyle: RythemTypography.bodySmall.copyWith(color: themeColors.textTertiary),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: isInferring
                            ? null
                            : () async {
                                final topic = topicController.text.trim();
                                if (topic.isEmpty) return;
                                setModalState(() {
                                  isInferring = true;
                                  outputText = null;
                                  latencyMs = null;
                                });
                                final sw = Stopwatch()..start();
                                try {
                                  final result = await _localInferenceService.answerQuery(
                                    prompt: topic,
                                    roadmapId: _roadmapId,
                                    roadmapTitle: _roadmapTitle,
                                  );
                                  sw.stop();
                                  setModalState(() {
                                    outputText = result;
                                    latencyMs = sw.elapsedMilliseconds;
                                    isInferring = false;
                                  });
                                } catch (e) {
                                  sw.stop();
                                  setModalState(() {
                                    outputText = 'Inference error: $e';
                                    isInferring = false;
                                  });
                                }
                              },
                        icon: isInferring ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
                        label: isInferring ? 'Running Inference...' : 'Run Test Inference',
                        variant: GlassButtonVariant.primary,
                      ),
                    ),
                    if (isInferring) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ),
                    ] else if (outputText != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'AI MENTOR OUTPUT',
                                  style: RythemTypography.labelSmall.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: themeColors.textSecondary,
                                  ),
                                ),
                                if (latencyMs != null)
                                  Text(
                                    '${latencyMs}ms',
                                    style: RythemTypography.labelSmall.copyWith(
                                      fontSize: 9,
                                      color: themeColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              outputText!,
                              style: RythemTypography.bodySmall.copyWith(
                                color: themeColors.textPrimary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: themeColors.canvasGradient,
        ),
        child: Stack(
          children: [
            // Persistent 4-Tab Immediate Stack with zero lag & preserved scroll states
            Positioned.fill(
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

            // Floating Frosted Glass Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, topPadding + 8, 20, 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xB3090A0D) : const Color(0xCCFFFFFF),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x18000000),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'RYTHEM',
                        style: RythemTypography.brandLogo.copyWith(
                          color: themeColors.textPrimary,
                          letterSpacing: 4.0,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
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
      onOpenRoadmapDetail: _openRoadmapDetail,
      onApplyPacingDecision: (roadmap, decision) async {
        await _pacingService.applyPacingDecision(roadmap.id, decision);
        await _loadDatabaseState();
      },
    );
  }

  void _openRoadmapDetail(RoadmapEntity roadmap) {
    HapticFeedback.lightImpact();
    final chapters = _chaptersByRoadmap[roadmap.id] ?? [];
    final beats = _beatsByRoadmap[roadmap.id] ?? [];

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoadmapDetailScreen(
          roadmap: roadmap,
          chapters: chapters,
          beats: beats,
          onBeatToggled: _setBeatCompletion,
          onArchiveRoadmap: _handleArchiveRoadmap,
          onRestoreRoadmap: _handleRestoreRoadmap,
          onAttachResource: _handleAttachResource,
          onAttachResourceToBeat: _handleAttachResourceToBeat,
        ),
      ),
    );
  }

  Future<void> _handleCreateTrack({
    required String title,
    required String category,
    required DateTime targetDate,
    String? resourceUrl,
    String? syllabusText,
  }) async {
    if (syllabusText != null && syllabusText.trim().isNotEmpty) {
      final parsed = SyllabusParser.parse(syllabusText, defaultTitle: title);
      await _ingestionService.ingestFromSyllabus(
        title: title,
        category: category,
        targetDate: targetDate,
        syllabus: parsed,
        resourceUrl: resourceUrl,
      );
    } else if (resourceUrl != null && resourceUrl.isNotEmpty) {
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
      await _ingestionService.attachResourceToRoadmap(
        roadmapId: roadmapId,
        resourceUrl: resourceUrl,
      );
      await _loadDatabaseState();
    } catch (e) {
      debugPrint('Error attaching resource: $e');
      rethrow;
    }
  }

  Future<void> _handleAttachResourceToBeat(String beatId, String resourceUrl) async {
    try {
      await _ingestionService.attachResourceToBeat(
        beatId: beatId,
        resourceUrl: resourceUrl,
      );
      await _loadDatabaseState();
    } catch (e) {
      debugPrint('Error attaching resource to beat: $e');
      rethrow;
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
      onAttachResourceToBeat: _handleAttachResourceToBeat,
    );
  }

  Widget _buildMetricsTab(RythemThemeColors themeColors, bool isDark) {
    return MetricsScreen(
      roadmaps: _allRoadmaps,
      beatsByRoadmap: _beatsByRoadmap,
      budgetsByRoadmap: _budgetsByRoadmap,
      activeBudget: _pacingBudget,
      currentStreak: _currentStreak,
      recentActivity: _recentActivity,
      simulatedNow: _simulatedNow,
      onOpenRoadmapDetail: _openRoadmapDetail,
      onSimulateMissedDay: _simulateMissedDay,
      onCompleteTodaysQuota: _completeTodaysQuota,
      onSimulate3DayLag: _simulate3DayLag,
      onResetSimulationClock: _resetSimulationClock,
    );
  }

  Widget _buildSettingsTab(RythemThemeColors themeColors, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, topPadding + 64, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SETTINGS',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textTertiary,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Appearance (Compact Segmented Control)
          Text(
            'APPEARANCE',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _buildAppearanceSegmented(themeColors, isDark),
          const SizedBox(height: 24),

          // 2. Pacing Calibration (Preset Selector: Light 45d / Normal 30d / Intense 14d)
          Text(
            'PACING CALIBRATION',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _buildCalibrationSegmented(themeColors, isDark),
          const SizedBox(height: 24),

          // 3. On-Device AI Manager
          Text(
            'ON-DEVICE AI',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Local Intelligence Engine',
                      style: RythemTypography.titleSmall.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _activeModelTier == ModelTier.fallback
                            ? 'FALLBACK'
                            : _activeModelTier.name.toUpperCase(),
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Live Download Progress Bar (only visible when actively downloading)
                ValueListenableBuilder<DownloadProgress?>(
                  valueListenable: _modelDownloadManager.downloadProgressNotifier,
                  builder: (context, progress, _) {
                    if (progress != null && !progress.isCompleted && progress.error == null) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0E000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorderHighlight : const Color(0x24000000),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Downloading ${ModelInfo.forTier(progress.tier).displayName}...',
                                  style: RythemTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: themeColors.textPrimary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _modelDownloadManager.cancelDownload();
                                    _showToast('Download cancelled');
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: RythemTypography.labelSmall.copyWith(
                                      color: themeColors.textTertiary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.progress > 0 ? progress.progress : null,
                                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                valueColor: AlwaysStoppedAnimation<Color>(themeColors.textPrimary),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${progress.formattedReceived} / ${progress.formattedTotal}',
                                  style: RythemTypography.bodySmall.copyWith(
                                    color: themeColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  progress.formattedProgress,
                                  style: RythemTypography.labelSmall.copyWith(
                                    color: themeColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                _buildModelOptionTile(
                  info: ModelInfo.fallback,
                  isDownloaded: true,
                  isActive: _activeModelTier == ModelTier.fallback,
                  themeColors: themeColors,
                  isDark: isDark,
                  onSelect: () => _handleSelectActiveModel(ModelTier.fallback),
                ),
                _buildModelOptionTile(
                  info: ModelInfo.compact,
                  isDownloaded: _compactDownloaded,
                  isActive: _activeModelTier == ModelTier.compact,
                  themeColors: themeColors,
                  isDark: isDark,
                  onSelect: () => _handleSelectActiveModel(ModelTier.compact),
                  onDownload: () => _handleDownloadModel(ModelTier.compact),
                  onDelete: () => _handleDeleteModel(ModelTier.compact),
                ),
                _buildModelOptionTile(
                  info: ModelInfo.balanced,
                  isDownloaded: _balancedDownloaded,
                  isActive: _activeModelTier == ModelTier.balanced,
                  themeColors: themeColors,
                  isDark: isDark,
                  onSelect: () => _handleSelectActiveModel(ModelTier.balanced),
                  onDownload: () => _handleDownloadModel(ModelTier.balanced),
                  onDelete: () => _handleDeleteModel(ModelTier.balanced),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    onPressed: _showAiMentorTestModal,
                    icon: Icons.auto_awesome_rounded,
                    label: 'Test AI Mentor Inference',
                    variant: GlassButtonVariant.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quiet Version Metadata
          Center(
            child: Text(
              'Rythem • Local First • v1.0.0',
              style: RythemTypography.labelSmall.copyWith(
                color: themeColors.textTertiary.withOpacity(0.6),
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSegmented(RythemThemeColors themeColors, bool isDark) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
        ),
      ),
      child: Row(
        children: [
          _buildSegmentButton('System', ThemeMode.system, themeColors, isDark),
          _buildSegmentButton('Dark', ThemeMode.dark, themeColors, isDark),
          _buildSegmentButton('Light', ThemeMode.light, themeColors, isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    String label,
    ThemeMode mode,
    RythemThemeColors themeColors,
    bool isDark,
  ) {
    final isSelected = widget.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onThemeModeChanged(mode);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withOpacity(0.14) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: RythemTypography.labelSmall.copyWith(
              color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalibrationSegmented(RythemThemeColors themeColors, bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
        ),
      ),
      child: Row(
        children: [
          _buildCalibrationPill('light', 'Light', '45d', themeColors, isDark),
          _buildCalibrationPill('normal', 'Normal', '30d', themeColors, isDark),
          _buildCalibrationPill('intense', 'Intense', '14d', themeColors, isDark),
        ],
      ),
    );
  }

  Widget _buildCalibrationPill(
    String option,
    String label,
    String pace,
    RythemThemeColors themeColors,
    bool isDark,
  ) {
    final isSelected = _pacingCalibration == option;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _pacingCalibration = option);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withOpacity(0.14) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: RythemTypography.labelSmall.copyWith(
                  color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 11.5,
                ),
              ),
              Text(
                pace,
                style: RythemTypography.bodySmall.copyWith(
                  color: isSelected ? themeColors.textSecondary : themeColors.textTertiary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelOptionTile({
    required ModelInfo info,
    required bool isDownloaded,
    required bool isActive,
    required RythemThemeColors themeColors,
    required bool isDark,
    required VoidCallback onSelect,
    VoidCallback? onDownload,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08))
            : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? (isDark ? themeColors.glassBorderHighlight : Colors.black87)
              : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
          width: isActive ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: (info.tier == ModelTier.fallback || isDownloaded) ? onSelect : onDownload,
                child: Icon(
                  isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: isActive ? themeColors.textPrimary : themeColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        info.displayName,
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        info.formattedSize,
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (info.tier != ModelTier.fallback) ...[
                const SizedBox(width: 10),
                if (!isDownloaded)
                  GlassButton(
                    label: 'Download',
                    icon: Icons.download_rounded,
                    height: 28,
                    variant: GlassButtonVariant.secondary,
                    onPressed: onDownload,
                  )
                else ...[
                  if (!isActive)
                    GlassButton(
                      label: 'Activate',
                      height: 28,
                      variant: GlassButtonVariant.ghost,
                      onPressed: onSelect,
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: themeColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              info.description,
              style: RythemTypography.bodySmall.copyWith(
                color: themeColors.textTertiary,
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ),
          if (info.tier != ModelTier.fallback && isDownloaded && !isActive)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 4),
              child: Text(
                'Downloaded on device. Tap "Activate" to use.',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textSecondary,
                  fontSize: 9.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

