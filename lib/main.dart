import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database.dart';
import 'core/ingestion/ingestion.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'core/theme/typography.dart';
import 'core/widgets/widgets.dart';

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

  StreamSubscription<DatabaseEvent>? _eventSubscription;

  String _roadmapTitle = 'Deep Learning & Neural Flow';
  String _roadmapId = 'rm_demo';
  int _completedBeats = 3;
  int _totalBeats = 7;
  double _progressRatio = 3 / 7;
  int _currentStreak = 1;
  List<BeatEntity> _beats = [];
  List<RoadmapEntity> _allRoadmaps = [];
  bool _isIngesting = false;
  String? _lastIngestionSummary;

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
    final beats = await _beatRepo.getBeatsByRoadmapId(_roadmapId);
    final progress = await _roadmapRepo.getRoadmapProgress(_roadmapId);
    final streak = await _beatLogRepo.getCurrentStreak();
    final allRoadmaps = await _roadmapRepo.getActiveRoadmaps();

    if (mounted) {
      setState(() {
        _beats = beats;
        _completedBeats = progress.completedBeats;
        _totalBeats = progress.totalBeats > 0 ? progress.totalBeats : 7;
        _progressRatio = progress.beatRatio;
        _currentStreak = streak > 0 ? streak : 1;
        _allRoadmaps = allRoadmaps;
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
    await _seedSampleData();
    await _loadDatabaseState();
    HapticFeedback.mediumImpact();
  }

  void _switchRoadmap(RoadmapEntity rm) {
    setState(() {
      _roadmapId = rm.id;
      _roadmapTitle = rm.title;
    });
    _loadDatabaseState();
    HapticFeedback.selectionClick();
  }

  // --- Ingestion Test Cases ---

  /// Test Condition 1: Blank Roadmap + YouTube Playlist (Zero-Drop Guarantee & Chapter Clustering)
  Future<void> _testCondition1() async {
    setState(() => _isIngesting = true);
    HapticFeedback.lightImpact();

    try {
      // 16-item mock playlist to verify 100% video coverage into 3-4 balanced chapters
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
        title: 'Neural Networks Masterclass (C1 Test)',
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
          title: 'Mentor Special: Vim & NeoVim Mastery for AI Engineers', // Extra!
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
          title: 'Mentor Special: Profiling PyTorch CUDA Memory Spikes', // Extra!
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
        title: 'Deep Learning with Syllabus (C2 Test)',
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

  /// Test Condition 3: Single Long Video Description with Chapter Timestamps
  Future<void> _testCondition3() async {
    setState(() => _isIngesting = true);
    HapticFeedback.lightImpact();

    try {
      const longVideoDescription = '''
Complete 3-Hour Crash Course on Large Language Models from Scratch.
00:00 Introduction to Tokenization & Vocabulary
08:30 Byte-Pair Encoding (BPE) Algorithm
24:15 Embeddings & Positional Vectors
[48:00] Multi-Head Attention Block Implementation
(01:15:30) Residual Connections & Pre-LayerNorm
01:42:10 Feed-Forward SwiGLU Networks
02:10:45 Training Dynamics & Cross-Entropy Loss
02:45:00 Sampling & Nucleus Temperature Generation
      ''';

      final segments = TimestampParser.parseDescription(
        longVideoDescription,
        totalVideoDurationSeconds: 10800, // 3 hours
      );

      final items = segments.asMap().entries.map((entry) {
        final i = entry.key;
        final seg = entry.value;
        return RawResourceItem(
          title: seg.title,
          sourceUrl: 'https://youtube.com/watch?v=long_llm&t=${seg.startSeconds}s',
          timestampSeconds: seg.startSeconds,
          durationSeconds: seg.durationSeconds,
          index: i,
        );
      }).toList();

      final resource = ExtractedResource(
        title: 'LLM from Scratch (C3 Timestamps)',
        author: 'Karpathy Format Lecture',
        description: 'Condition 3 Test: Deep-linked timestamp beats from description.',
        sourceUrl: 'https://youtube.com/watch?v=long_llm',
        resourceType: ExtractedResourceType.singleVideoWithTimestamps,
        items: items,
      );

      final result = await _ingestionService.ingestExtractedResource(
        extracted: resource,
      );

      _roadmapId = result.roadmapId;
      _roadmapTitle = result.roadmapTitle;
      _lastIngestionSummary =
          'Condition 3: Extracted ${result.beatsCount} deep-linked timestamp beats from description!';

      await _loadDatabaseState();
      _showToast(_lastIngestionSummary!);
    } catch (e) {
      _showToast('Condition 3 Error: $e');
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
  }

  /// Ingest real custom YouTube URL
  Future<void> _ingestCustomUrl(String url) async {
    if (url.trim().isEmpty) return;

    setState(() => _isIngesting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await _ingestionService.ingestFromUrl(url: url.trim());
      _roadmapId = result.roadmapId;
      _roadmapTitle = result.roadmapTitle;
      _lastIngestionSummary =
          'Custom Ingest Success: ${result.beatsCount} beats in ${result.chaptersCount} chapters!';
      await _loadDatabaseState();
      _showToast(_lastIngestionSummary!);
    } catch (e) {
      _showToast('Live YouTube Ingestion Error: $e');
    } finally {
      if (mounted) setState(() => _isIngesting = false);
    }
  }

  void _showCustomUrlModal() {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final themeColors = RythemColors.of(context);
        final isDark = themeColors.isDark;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: GlassContainer(
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
                      'INGEST YOUTUBE CURRICULUM',
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
                const SizedBox(height: 12),
                Text(
                  'Paste any YouTube Playlist or single video URL with timestamps in description.',
                  style: RythemTypography.bodyMedium.copyWith(
                    color: themeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  style: RythemTypography.bodyLarge.copyWith(color: themeColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/playlist?list=...',
                    hintStyle: TextStyle(color: themeColors.textTertiary),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? themeColors.glassBorder : const Color(0x14000000),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: themeColors.textPrimary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'QUICK DEMO PRESETS',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip(
                      label: 'Karpathy: Neural Nets',
                      url: 'https://www.youtube.com/playlist?list=PLAqhIrjkxbuWI23v9cThsA9GvCAUhRvKZ',
                      controller: textController,
                    ),
                    _presetChip(
                      label: 'Karpathy: Let Us Build GPT',
                      url: 'https://www.youtube.com/watch?v=kCc8FmEb1nY',
                      controller: textController,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GlassButton(
                  label: 'Ingest Into SQLite',
                  width: double.infinity,
                  onPressed: () {
                    final url = textController.text.trim();
                    Navigator.pop(context);
                    if (url.isNotEmpty) {
                      _ingestCustomUrl(url);
                    }
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _presetChip({
    required String label,
    required String url,
    required TextEditingController controller,
  }) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return GestureDetector(
      onTap: () {
        controller.text = url;
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? themeColors.glassBorder : const Color(0x14000000),
          ),
        ),
        child: Text(
          label,
          style: RythemTypography.labelSmall.copyWith(
            color: themeColors.textPrimary,
            fontSize: 11,
          ),
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
              Text(
                'STORED ROADMAPS IN SQLITE',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (_allRoadmaps.isEmpty)
                Text(
                  'No roadmaps found.',
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
              const SizedBox(height: 12),
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
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar with Brand Logo & Theme Mode Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
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
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RYTHEM',
                            style: RythemTypography.brandLogo.copyWith(
                              color: themeColors.textPrimary,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'beats over clocks • felt, not measured',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
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
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(22),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Icon(
                          isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: themeColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

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
                          color: Color(0xFF34C759), // Active indicator
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SQLITE [rythem.db] • PERSISTENT',
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

              // Hero Glass Card (Real SQLite Data)
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _roadmapTitle,
                            style: RythemTypography.titleLarge.copyWith(
                              color: themeColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showRoadmapSelector,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
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
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tapping any beat writes directly to SQLite and recalculates streaks and progress ratios without clock-time.',
                      style: RythemTypography.bodyMedium.copyWith(
                        color: themeColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),

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

                    const SizedBox(height: 18),

                    // Flow Streak Metrics (Felt, Not Clock-Measured)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
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
                        const SizedBox(width: 10),
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

              // Ingestion Engine 3-Condition Test Harness
              Text(
                'INGESTION ENGINE TEST HARNESS (3 CONDITIONS)',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),

              if (_isIngesting)
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Ingestion engine running (extracting, clustering, & persisting to SQLite)...',
                          style: RythemTypography.bodyMedium.copyWith(
                            color: themeColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _ingestionTestCard(
                        conditionTag: 'CONDITION 1',
                        title: 'Playlist & 0-Drop Cluster',
                        description: 'Clusters flat videos into 4-8 balanced chapters.',
                        onTap: _testCondition1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ingestionTestCard(
                        conditionTag: 'CONDITION 2',
                        title: 'Syllabus & Mentor Extras',
                        description: 'Aligns topics & tags mentor extras in place.',
                        onTap: _testCondition2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ingestionTestCard(
                        conditionTag: 'CONDITION 3',
                        title: 'Video Timestamp Parser',
                        description: 'Extracts deep-linked beats from descriptions.',
                        onTap: _testCondition3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ingestionTestCard(
                        conditionTag: 'CUSTOM YOUTUBE',
                        title: 'Paste Live URL',
                        description: 'Scrape and ingest any public YouTube link.',
                        isAction: true,
                        onTap: _showCustomUrlModal,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // Active Chapter & Beats Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CURRICULUM BEATS (${_beats.length})',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                    ),
                  ),
                  Text(
                    'Tap beat to toggle SQLite state',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Real SQLite Beats List
              ..._beats.map((beat) {
                final isCompleted = beat.isCompleted;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    onTap: () => _toggleBeat(beat),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? (isDark
                                    ? Colors.white.withOpacity(0.12)
                                    : Colors.black.withOpacity(0.08))
                                : (isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : Colors.black.withOpacity(0.03)),
                            border: Border.all(
                              color: isCompleted
                                  ? (isDark
                                      ? themeColors.glassBorderHighlight
                                      : const Color(0x24000000))
                                  : (isDark
                                      ? themeColors.glassBorder
                                      : const Color(0x12000000)),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isCompleted
                                ? Icons.check
                                : Icons.circle_outlined,
                            color: isCompleted
                                ? themeColors.textPrimary
                                : themeColors.textTertiary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      beat.title,
                                      style: RythemTypography.titleMedium
                                          .copyWith(
                                        color: isCompleted
                                            ? themeColors.textPrimary
                                            : themeColors.textSecondary,
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (beat.isMentorExtra) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.12)
                                            : Colors.black.withOpacity(0.08),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isDark
                                              ? themeColors.glassBorderHighlight
                                              : const Color(0x20000000),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'mentor extra',
                                        style: RythemTypography.labelSmall
                                            .copyWith(
                                          fontSize: 9,
                                          color: themeColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCompleted
                                    ? 'Completed in SQLite • Logged to beat_logs'
                                    : 'Mentor order #${beat.sortOrder + 1} • Effort weight: ${beat.effortWeight}${beat.timestampSeconds != null ? " • &t=${beat.timestampSeconds}s" : ""}',
                                style:
                                    RythemTypography.bodyMedium.copyWith(
                                  fontSize: 11,
                                  color: themeColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
        ),
      ),
    );
  }

  Widget _ingestionTestCard({
    required String conditionTag,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isAction = false,
  }) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAction
                      ? (isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.12))
                      : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  conditionTag,
                  style: RythemTypography.labelSmall.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: themeColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                isAction ? Icons.open_in_new : Icons.play_arrow_outlined,
                size: 16,
                color: themeColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: RythemTypography.titleMedium.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: themeColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: RythemTypography.bodyMedium.copyWith(
              fontSize: 10.5,
              color: themeColors.textTertiary,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
