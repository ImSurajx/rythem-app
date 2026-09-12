import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/database/database.dart';
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

  StreamSubscription<DatabaseEvent>? _eventSubscription;

  String _roadmapTitle = 'Deep Learning & Neural Flow';
  String _roadmapId = 'rm_demo';
  int _completedBeats = 3;
  int _totalBeats = 7;
  double _progressRatio = 3 / 7;
  int _currentStreak = 1;
  List<BeatEntity> _beats = [];

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

    if (mounted) {
      setState(() {
        _beats = beats;
        _completedBeats = progress.completedBeats;
        _totalBeats = progress.totalBeats > 0 ? progress.totalBeats : 7;
        _progressRatio = progress.beatRatio;
        _currentStreak = streak > 0 ? streak : 1;
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

                    const SizedBox(height: 28),

                    // Database Connection Badge
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
                          'SQLITE [rythem.db] • LIVE PERSISTENCE ACTIVE',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                            letterSpacing: 1.0,
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
                            children: [
                              Expanded(
                                child: Text(
                                  _roadmapTitle,
                                  style: RythemTypography.titleLarge.copyWith(
                                    color: themeColors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
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
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Stored in on-device SQLite. Tapping beats updates the local DBMS instantly and persists across app force-quits.',
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
                                '$_currentStreak Beat Streak 🔥',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GlassProgressBar(
                            progress: _progressRatio,
                            height: 8,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Interactive Beat Tile Cards (Direct from SQLite)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SQLITE BEATS TABLE (${_beats.length} INGESTED)',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                          ),
                        ),
                        Text(
                          'TAP TO TOGGLE',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ..._beats.map((beat) {
                      final isCompleted = beat.isCompleted;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                                                  ? Colors.white.withOpacity(0.08)
                                                  : Colors.black.withOpacity(0.06),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'mentor extra',
                                              style: RythemTypography.labelSmall
                                                  .copyWith(
                                                fontSize: 9,
                                                color: themeColors.textTertiary,
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
                                          : 'Pending in mentor chronological order (weight: ${beat.effortWeight})',
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
}

