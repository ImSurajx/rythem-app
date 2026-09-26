import 'dart:async';
import 'dart:convert';
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
import 'core/backup/services/backup_service.dart';
import 'core/backup/services/auto_backup_manager.dart';
import 'core/revision/models/revision_item.dart';
import 'core/revision/services/revision_service.dart';
import 'features/flow/widgets/mark_revision_sheet.dart';
import 'core/navigation/smooth_page_route.dart';
import 'core/updater/updater.dart';
import 'features/settings/widgets/software_update_card.dart';
import 'features/settings/widgets/update_modal_sheet.dart';
import 'core/ingestion/services/resource_sync_service.dart';

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
  ThemePalette _themePalette = ThemePalette.aurora;
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
      final modeVal = await _settingsRepo.getSetting('theme_mode');
      final paletteVal = await _settingsRepo.getSetting('theme_palette');

      ThemeMode mode = ThemeMode.system;
      if (modeVal == 'dark') mode = ThemeMode.dark;
      if (modeVal == 'light') mode = ThemeMode.light;

      ThemePalette palette = ThemePalette.aurora;
      if (paletteVal != null) {
        for (final p in ThemePalette.values) {
          if (p.name == paletteVal) {
            palette = p;
            break;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasCompletedOnboarding = (val == 'true');
          _themeMode = mode;
          _themePalette = palette;
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
    _settingsRepo.setSetting(
      'theme_mode',
      mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'),
    );
  }

  void _setThemePalette(ThemePalette palette) {
    setState(() {
      _themePalette = palette;
    });
    _settingsRepo.setSetting('theme_palette', palette.name);
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
        themePalette: _themePalette,
        onThemePaletteChanged: _setThemePalette,
      );
    }

    final isDark = _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    final themeColors = RythemColors.forPalette(_themePalette, isDark: isDark);

    return RythemThemeScope(
      colors: themeColors,
      child: MaterialApp(
        title: 'Rythem',
        debugShowCheckedModeBanner: false,
        theme: RythemTheme.lightTheme,
        darkTheme: RythemTheme.darkTheme,
        themeMode: _themeMode,
        home: home,
      ),
    );
  }
}

class DesignSystemShowcaseScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ThemePalette themePalette;
  final ValueChanged<ThemePalette>? onThemePaletteChanged;

  const DesignSystemShowcaseScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.themePalette = ThemePalette.aurora,
    this.onThemePaletteChanged,
  });

  @override
  State<DesignSystemShowcaseScreen> createState() =>
      _DesignSystemShowcaseScreenState();
}

class _DesignSystemShowcaseScreenState
    extends State<DesignSystemShowcaseScreen> with WidgetsBindingObserver {
  final _roadmapRepo = RoadmapRepository();
  final _chapterRepo = ChapterRepository();
  final _beatRepo = BeatRepository();
  final _beatLogRepo = BeatLogRepository();
  final _appSettingsRepo = AppSettingsRepository();
  final _backupService = BackupService();
  late final _autoBackupManager = AutoBackupManager(
    backupService: _backupService,
    settingsRepo: _appSettingsRepo,
  );
  BackupSnapshotInfo? _latestAutoBackup;
  String _backupLocationDescription = 'Documents > Rythem > Backups';
  bool _isPerformingAutoBackup = false;
  bool _hasCheckedDisasterRecovery = false;
  WeeklyStudySchedule _weeklySchedule = WeeklyStudySchedule.defaultSchedule();

  late final _ingestionService = CurriculumIngestionService(
    roadmapRepo: _roadmapRepo,
    chapterRepo: _chapterRepo,
    beatRepo: _beatRepo,
  );
  late final _pacingService = PacingService(
    roadmapRepo: _roadmapRepo,
    beatRepo: _beatRepo,
    beatLogRepo: _beatLogRepo,
    settingsRepo: _appSettingsRepo,
  );
  final _modelDownloadManager = ModelDownloadManager();
  late final _localInferenceService = LocalInferenceService(
    downloadManager: _modelDownloadManager,
    roadmapRepo: _roadmapRepo,
    beatRepo: _beatRepo,
    pacingService: _pacingService,
  );
  LocalInferenceService get inferenceService => _localInferenceService;
  late final _revisionService = RevisionService(settingsRepo: _appSettingsRepo);
  List<RevisionItem> _revisionItems = [];
  List<RevisionItem> _allShelfItems = [];

  late final _githubReleaseService = GithubReleaseService();
  late final _nativeInstallerService = NativeInstallerService();
  late final _resourceSyncService = ResourceSyncService();
  UpdateReleaseInfo? _latestReleaseInfo;
  bool _isCheckingForUpdates = false;

  StreamSubscription<DatabaseEvent>? _eventSubscription;

  String _roadmapId = '';
  int _currentStreak = 0;
  List<ChapterEntity> _chapters = [];
  List<BeatEntity> _beats = [];
  Map<String, List<ChapterEntity>> _chaptersByRoadmap = {};
  Map<String, List<BeatEntity>> _beatsByRoadmap = {};
  Map<String, PacingBudget> _budgetsByRoadmap = {};
  List<RoadmapEntity> _allRoadmaps = [];
  List<DailyBeatCount> _recentActivity = [];

  PacingBudget? _pacingBudget;
  int _currentTabIndex = 0;

  ModelTier _activeModelTier = ModelTier.fallback;
  bool _compactDownloaded = false;
  bool _balancedDownloaded = false;
  Set<String> _delayedBeatIds = {'beat_delayed_sample'};
  bool _hasRequestedRevision = false;
  bool _isScanningRevision = false;
  bool _isLoadingDbState = false;
  bool _hasPendingDbReload = false;

  /// Tracks active in-flight toggles to guarantee SQLite reads never clobber optimistic state
  final Map<String, bool> _pendingBeatToggles = {};
  Timer? _debounceReloadTimer;

  void _scheduleDebouncedReload([int delayMs = 120]) {
    _debounceReloadTimer?.cancel();
    _debounceReloadTimer = Timer(Duration(milliseconds: delayMs), () {
      _requestDatabaseReload();
    });
  }

  Future<void> _requestDatabaseReload() async {
    if (_isLoadingDbState) {
      _hasPendingDbReload = true;
      return;
    }
    _isLoadingDbState = true;
    _hasPendingDbReload = false;
    try {
      await _loadDatabaseState();
    } finally {
      _isLoadingDbState = false;
      if (_hasPendingDbReload) {
        _hasPendingDbReload = false;
        unawaited(_requestDatabaseReload());
      }
    }
  }

  Future<void> _lastToggleOperation = Future.value();

  Future<void> _setBeatCompletion(BeatEntity beat, bool isCompleted) {
    // 1. Instant optimistic update so UI is immediately reactive
    _pendingBeatToggles[beat.id] = isCompleted;

    final updatedBeat = beat.copyWith(
      isCompleted: isCompleted,
      completedAt: isCompleted ? DateTime.now() : null,
      clearCompletedAt: !isCompleted,
    );
    if (mounted) {
      setState(() {
        _beats = _beats.map((b) => b.id == beat.id ? updatedBeat : b).toList();
        final rmList = _beatsByRoadmap[beat.roadmapId];
        if (rmList != null) {
          _beatsByRoadmap[beat.roadmapId] =
              rmList.map((b) => b.id == beat.id ? updatedBeat : b).toList();
        }
      });
    }

    // 2. Persist to SQLite and reload sequentially so rapid toggles never race
    final op = _lastToggleOperation.then((_) async {
      await _beatRepo.toggleBeatCompletion(beat.id, isCompleted: isCompleted);
      if (isCompleted && _delayedBeatIds.contains(beat.id)) {
        final updated = Set<String>.from(_delayedBeatIds)..remove(beat.id);
        await _appSettingsRepo.setSetting('delayed_beat_ids', jsonEncode(updated.toList()));
        if (mounted) {
          setState(() {
            _delayedBeatIds = updated;
          });
          _showToast('Delayed beat completed: "${beat.title}"! 🎉');
        }
      }
      _pendingBeatToggles.remove(beat.id);
      _scheduleDebouncedReload(80);
    }).catchError((e) {
      _pendingBeatToggles.remove(beat.id);
      debugPrint('Error in sequential toggle operation: $e');
    });

    _lastToggleOperation = op;
    return op;
  }

  Future<void> _handleSplitBeat(BeatEntity beat, int totalParts) async {
    await _beatRepo.updateBeatParts(beat.id, totalParts);
    await _loadDatabaseState();
    if (mounted) {
      _showToast(
        totalParts > 1
            ? 'Split into $totalParts parts'
            : 'Reset to single task',
      );
    }
  }

  Future<void> _handleIncrementBeatPart(BeatEntity beat) async {
    final updated = await _beatRepo.incrementBeatPart(beat.id);
    await _loadDatabaseState();
    if (mounted && updated != null) {
      if (updated.isCompleted) {
        _showToast('All ${updated.totalParts} parts completed! 🏆');
      } else {
        _showToast('Part ${updated.completedParts} of ${updated.totalParts} complete! Streak recorded 🔥');
      }
    }
  }

  Future<void> _handleDecrementBeatPart(BeatEntity beat) async {
    await _beatRepo.decrementBeatPart(beat.id);
    await _loadDatabaseState();
  }

  Future<void> _handleRequestRevisionRecommendations() async {
    if (_isScanningRevision) return;
    setState(() => _isScanningRevision = true);
    HapticFeedback.mediumImpact();
    _showToast('AI Mentor scanning tracker & memory decay curves...');
    try {
      final budget = _budgetsByRoadmap[_roadmapId];
      final finalBeats = _beatsByRoadmap[_roadmapId] ?? [];
      final upcomingFocus = budget?.todaysBeats.isNotEmpty == true
          ? budget!.todaysBeats
          : finalBeats.where((b) => !b.isCompleted).take(2).toList();

      final items = await _revisionService.getDailyRevisionRecommendations(
        roadmaps: _allRoadmaps,
        beatsByRoadmap: _beatsByRoadmap,
        upcomingFocusBeats: upcomingFocus,
        todayEffortBudget: budget?.todayEffortShare,
        inferenceService: _localInferenceService,
      );

      if (mounted) {
        setState(() {
          _hasRequestedRevision = true;
          _isScanningRevision = false;
          _revisionItems = items;
        });
        if (items.isEmpty) {
          _showToast('Trackers are fresh! No concepts need urgent revision today.');
        } else {
          _showToast('AI recommended ${items.length} high-yield topic${items.length == 1 ? '' : 's'} to revise');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningRevision = false);
        _showToast('Could not analyze revision: $e');
      }
    }
  }

  Future<void> _handleToggleBeatDelay(BeatEntity beat) async {
    HapticFeedback.selectionClick();
    final updated = Set<String>.from(_delayedBeatIds);
    final wasDelayed = updated.contains(beat.id);
    if (wasDelayed) {
      updated.remove(beat.id);
      _showToast('Resumed "${beat.title}" into active flow');
    } else {
      updated.add(beat.id);
      _showToast('Delayed "${beat.title}" — ready for later testing');
    }
    await _appSettingsRepo.setSetting('delayed_beat_ids', jsonEncode(updated.toList()));
    if (mounted) {
      setState(() {
        _delayedBeatIds = updated;
      });
    }
  }

  Future<void> _handleUpdateTargetDate(RoadmapEntity roadmap, DateTime? newTargetDate) async {
    await _pacingService.updateRoadmapTargetDate(roadmap.id, newTargetDate);
    await _loadDatabaseState();
    if (mounted) {
      if (newTargetDate == null) {
        _showToast('Switched "${roadmap.title}" to Open Pace ⚪');
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final formatted = '${months[newTargetDate.month - 1]} ${newTargetDate.day}, ${newTargetDate.year}';
        _showToast('Target date updated to $formatted 🎯');
      }
    }
  }

  Future<void> _handleMarkRevised(RevisionItem item) async {
    final wasCompleted = item.isCompletedToday;
    final newCompletedState = !wasCompleted;
    final now = DateTime.now();
    final todayDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Instantly update in-memory state so strikethrough updates immediately without dropping items
    setState(() {
      _revisionItems = _revisionItems.map((r) {
        if (r.beatId == item.beatId) {
          return r.copyWith(
            isCompleted: newCompletedState,
            lastRevisedAt: newCompletedState ? now : null,
          );
        }
        return r;
      }).toList();
      _allShelfItems = _allShelfItems.map((r) {
        if (r.beatId == item.beatId) {
          return r.copyWith(
            isCompleted: newCompletedState,
            lastRevisedAt: newCompletedState ? now : null,
          );
        }
        return r;
      }).toList();
    });

    BeatEntity? beat;
    for (final beatList in _beatsByRoadmap.values) {
      final match = beatList.where((b) => b.id == item.beatId).firstOrNull;
      if (match != null) {
        beat = match;
        break;
      }
    }
    beat ??= await _beatRepo.getBeatById(item.beatId);
    beat ??= BeatEntity(
      id: item.beatId,
      chapterId: '',
      roadmapId: item.roadmapId,
      title: item.title,
      effortWeight: 1.0,
      sortOrder: 0,
      isCompleted: true,
      createdAt: now,
      updatedAt: now,
    );

    if (wasCompleted) {
      await _revisionService.unmarkTopicRevised(beat, roadmapTitle: item.roadmapTitle);
      await _beatLogRepo.removeBeatCompletion(
        beatId: beat.id,
        completedDate: todayDateStr,
      );
      _showToast(
        'Reopened "${item.title}" for revision',
        icon: Icons.history_rounded,
        accentColor: Colors.amber,
      );
    } else {
      await _revisionService.markTopicRevised(beat, roadmapTitle: item.roadmapTitle);
      final points = item.beatPoints;
      await _beatLogRepo.logBeatCompletion(
        beatId: beat.id,
        roadmapId: beat.roadmapId,
        completedDate: todayDateStr,
      );
      _showToast(
        '+${points.toStringAsFixed(1)} Beat Points! Revised "${item.title}"',
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFF10B981),
      );
    }
    final streak = await _beatLogRepo.getCurrentStreak();
    if (mounted) {
      setState(() => _currentStreak = streak);
    }
  }

  Future<void> _refreshRevisionShelf() async {
    final allShelf = await _revisionService.getRevisionShelfItems();
    final budget = _budgetsByRoadmap[_roadmapId];
    final finalBeats = _beatsByRoadmap[_roadmapId] ?? [];
    final upcomingFocus = budget?.todaysBeats.isNotEmpty == true
        ? budget!.todaysBeats
        : finalBeats.where((b) => !b.isCompleted).take(2).toList();

    List<RevisionItem> recs;
    if (_hasRequestedRevision) {
      recs = await _revisionService.getDailyRevisionRecommendations(
        roadmaps: _allRoadmaps,
        beatsByRoadmap: _beatsByRoadmap,
        upcomingFocusBeats: upcomingFocus,
        todayEffortBudget: budget?.todayEffortShare,
        inferenceService: _localInferenceService,
      );
    } else {
      recs = allShelf.where((i) => i.isDueToday).toList();
    }

    if (mounted) {
      setState(() {
        _allShelfItems = allShelf;
        _revisionItems = recs;
      });
    }
  }

  Future<void> _handleMarkForRevision(BeatEntity beat) async {
    final roadmap = _allRoadmaps.where((r) => r.id == beat.roadmapId).firstOrNull;
    final roadmapTitle = roadmap?.title ?? 'Active Tracker';
    final existingItem = _allShelfItems.where((i) => i.beatId == beat.id).firstOrNull;

    await MarkRevisionSheet.show(
      context,
      beat: beat,
      roadmapTitle: roadmapTitle,
      isInShelf: existingItem != null,
      currentIntervalDays: existingItem?.intervalDays ?? 3,
      currentNote: existingItem?.flagNote,
      onSave: (intervalDays, note) async {
        await _revisionService.addToRevisionShelf(
          beat: beat,
          roadmapTitle: roadmapTitle,
          intervalDays: intervalDays,
          note: note,
        );
        await _refreshRevisionShelf();
        _showToast(
          intervalDays != null
              ? 'Added to Revision Shelf (due in $intervalDays days)'
              : 'Saved to Revision Shelf (on demand)',
          icon: Icons.bookmark_added_rounded,
          accentColor: const Color(0xFF6366F1),
        );
      },
      onRemove: existingItem != null
          ? () async {
              await _revisionService.removeFromRevisionShelf(beat.id);
              await _refreshRevisionShelf();
              _showToast(
                'Removed from Revision Shelf',
                icon: Icons.bookmark_remove_outlined,
                accentColor: const Color(0xFFEF4444),
              );
            }
          : null,
    );
  }

  Future<void> _handleUnshelf(RevisionItem item) async {
    await _revisionService.removeFromRevisionShelf(item.beatId);
    await _refreshRevisionShelf();
    _showToast(
      'Removed "${item.title}" from Revision Shelf',
      icon: Icons.bookmark_remove_outlined,
      accentColor: const Color(0xFFEF4444),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSubscription = DatabaseEventBus.instance.stream.listen((event) {
      if (event.type == DatabaseEventType.beatToggled) {
        if (_pendingBeatToggles.isNotEmpty) return;
        _scheduleDebouncedReload(100);
      } else {
        _requestDatabaseReload();
      }
    });
    _modelDownloadManager.downloadProgressNotifier.addListener(_onModelDownloadUpdated);
    _initDatabaseAndSeed();
  }

  void _onModelDownloadUpdated() {
    final p = _modelDownloadManager.downloadProgressNotifier.value;
    if (p != null && p.isCompleted) {
      _loadModelStatus();
      if (mounted) {
        _showToast('${ModelInfo.forTier(p.tier).displayName} activated!');
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _debounceReloadTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _modelDownloadManager.downloadProgressNotifier.removeListener(_onModelDownloadUpdated);
    _eventSubscription?.cancel();
    _githubReleaseService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_modelDownloadManager.resumePendingDownload().then((_) {
        if (mounted) _loadModelStatus();
      }));
    }
  }

  Future<void> _initDatabaseAndSeed() async {
    try {
      unawaited(_modelDownloadManager.resumePendingDownload().then((_) {
        if (mounted) _loadModelStatus();
      }));
      final active = await _roadmapRepo.getActiveRoadmaps();
      if (active.isNotEmpty) {
        _roadmapId = active.first.id;
      } else {
        _roadmapId = '';
      }
      await _loadDatabaseState();

      if (active.isNotEmpty) {
        unawaited(_autoBackupManager.checkAndPerformDailyBackup());
      } else if (!_hasCheckedDisasterRecovery) {
        _hasCheckedDisasterRecovery = true;
        await _checkDisasterRecovery();
      }
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  Future<void> _loadDatabaseState() async {
    final allRoadmaps = await _roadmapRepo.getActiveRoadmaps();
    final latestBackup = await _autoBackupManager.getLatestAutoBackup();
    final backupLocation = await _autoBackupManager.getStorageLocationDescription();
    if (allRoadmaps.isEmpty) {
      final db = await DatabaseService.instance.database;
      try {
        await db.delete(DatabaseTables.beatLogs);
      } catch (_) {}
      try {
        await db.delete(DatabaseTables.dailyMissions);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _allRoadmaps = [];
          _roadmapId = '';
          _chapters = [];
          _beats = [];
          _chaptersByRoadmap = {};
          _beatsByRoadmap = {};
          _budgetsByRoadmap = {};
          _currentStreak = 0;
          _recentActivity = [];
          _pacingBudget = null;
          _latestAutoBackup = latestBackup;
          _backupLocationDescription = backupLocation;
        });
      }
      return;
    }

    if (_roadmapId.isEmpty || !allRoadmaps.any((r) => r.id == _roadmapId)) {
      _roadmapId = allRoadmaps.first.id;
    }

    // Fetch chapters, beats, and budgets for ALL roadmaps
    final chaptersByRoadmap = <String, List<ChapterEntity>>{};
    final beatsByRoadmap = <String, List<BeatEntity>>{};
    final budgetsByRoadmap = <String, PacingBudget>{};

    for (final rm in allRoadmaps) {
      final chs = await _chapterRepo.getChaptersByRoadmapId(rm.id);
      final rawBts = await _beatRepo.getBeatsByRoadmapId(rm.id);
      final bts = rawBts.map((b) {
        if (_pendingBeatToggles.containsKey(b.id)) {
          final pending = _pendingBeatToggles[b.id]!;
          return b.copyWith(
            isCompleted: pending,
            completedAt: pending ? (b.completedAt ?? DateTime.now()) : null,
            clearCompletedAt: !pending,
          );
        }
        return b;
      }).toList();
      chaptersByRoadmap[rm.id] = chs;
      beatsByRoadmap[rm.id] = bts;

      try {
        final b = await _pacingService.computePacingBudget(rm.id);
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
    final scheduleJson = await _appSettingsRepo.getSetting('study_intensity_schedule');
    final weeklySchedule = WeeklyStudySchedule.decode(scheduleJson);

    Set<String> delayedBeatIds = {};
    try {
      final rawDelayed = await _appSettingsRepo.getSetting('delayed_beat_ids');
      if (rawDelayed != null && rawDelayed.isNotEmpty) {
        final decoded = jsonDecode(rawDelayed) as List;
        delayedBeatIds = decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {
      delayedBeatIds = {};
    }

    final finalBeats = beatsByRoadmap[_roadmapId] ?? [];
    final upcomingFocus = budget?.todaysBeats.isNotEmpty == true
        ? budget!.todaysBeats
        : finalBeats.where((b) => !b.isCompleted).take(2).toList();
    final allShelfItems = await _revisionService.getRevisionShelfItems();
    List<RevisionItem> revisionItems = _revisionItems;
    if (_hasRequestedRevision) {
      revisionItems = await _revisionService.getDailyRevisionRecommendations(
        roadmaps: allRoadmaps,
        beatsByRoadmap: beatsByRoadmap,
        upcomingFocusBeats: upcomingFocus,
        todayEffortBudget: budget?.todayEffortShare,
        inferenceService: _localInferenceService,
      );
    } else if (allShelfItems.isNotEmpty) {
      revisionItems = allShelfItems.where((i) => i.isDueToday).toList();
    }

    if (mounted) {
      setState(() {
        _allRoadmaps = allRoadmaps;
        _chapters = chapters;
        _beats = finalBeats;
        _chaptersByRoadmap = chaptersByRoadmap;
        _beatsByRoadmap = beatsByRoadmap;
        _budgetsByRoadmap = budgetsByRoadmap;
        _currentStreak = streak;
        _recentActivity = recentActivity;
        _pacingBudget = budget;
        _weeklySchedule = weeklySchedule;
        _delayedBeatIds = delayedBeatIds;
        _allShelfItems = allShelfItems;
        _revisionItems = revisionItems;
        _latestAutoBackup = latestBackup;
        _backupLocationDescription = backupLocation;
      });
    }
    unawaited(_autoBackupManager.checkAndPerformDailyBackup());
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
    _modelDownloadManager.clearDownloadError();
    HapticFeedback.mediumImpact();
    _showToast('Downloading ${ModelInfo.forTier(tier).displayName}...');
    try {
      await _modelDownloadManager.downloadModel(tier);
      await _loadModelStatus();
      _showToast('${ModelInfo.forTier(tier).displayName} ready & activated!');
    } catch (e) {
      if (mounted) {
        GlassErrorDialog.show(
          context,
          title: 'Model Download Interrupted',
          message:
              'Failed to download ${ModelInfo.forTier(tier).displayName}. Partial progress is preserved and can resume automatically.',
          details: e.toString(),
          onRetry: () {
            _modelDownloadManager.clearDownloadError();
            _handleDownloadModel(tier);
          },
          onDismiss: () {
            _modelDownloadManager.clearDownloadError();
          },
        );
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

  void _switchRoadmap(RoadmapEntity rm) {
    setState(() {
      _roadmapId = rm.id;
    });
    _loadDatabaseState();
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

  void _showToast(String message, {IconData? icon, Color? accentColor}) {
    showGlassToast(context, message, icon: icon, accentColor: accentColor);
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: AmbientAuroraCanvas(
        palette: widget.themePalette,
        child: Stack(
          children: [
            // Persistent 4-Tab Smooth Cross-Fading Stack with zero lag & preserved scroll states
            Positioned.fill(
              child: FadeIndexedStack(
                index: _currentTabIndex,
                duration: const Duration(milliseconds: 200),
                children: [
                  _buildFlowTab(),
                  _buildExploreTab(themeColors, isDark),
                  _buildMetricsTab(themeColors, isDark),
                  _buildSettingsTab(themeColors, isDark),
                ],
              ),
            ),

            // Floating Frosted Glass Header with RepaintBoundary optimization
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: GlassBottomDock(
        selectedIndex: _currentTabIndex,
        onItemSelected: (idx) {
          if (_currentTabIndex != idx) {
            HapticFeedback.selectionClick();
            setState(() => _currentTabIndex = idx);
          }
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
      beatLogRepo: _beatLogRepo,
      onSwitchRoadmap: _showRoadmapSelector,
      onBeatToggled: _setBeatCompletion,
      delayedBeatIds: _delayedBeatIds,
      onToggleDelay: _handleToggleBeatDelay,
      onSplitBeat: _handleSplitBeat,
      onIncrementBeatPart: _handleIncrementBeatPart,
      onDecrementBeatPart: _handleDecrementBeatPart,
      revisionItems: _revisionItems,
      allShelfItems: _allShelfItems,
      onMarkRevised: _handleMarkRevised,
      onMarkForRevision: _handleMarkForRevision,
      onUnshelf: _handleUnshelf,
      onReschedule: (item) async {
        final beat = await _beatRepo.getBeatById(item.beatId);
        if (beat != null) {
          await _handleMarkForRevision(beat);
        }
      },
      onRequestRevisionRecommendations: _handleRequestRevisionRecommendations,
      isScanningRevision: _isScanningRevision,
      onExploreTracks: () => setState(() => _currentTabIndex = 1),
      onOpenRoadmapDetail: _openRoadmapDetail,
      onUpdateTargetDate: _handleUpdateTargetDate,
      onStartEarly: _handleStartRoadmapEarly,
      onStudyAhead: (roadmap) async {
        final pulled = await _pacingService.pullNextBeatIntoMission(roadmap.id);
        await _loadDatabaseState();
        if (mounted) {
          if (pulled != null) {
            _showToast('Added "${pulled.title}" to today\'s session');
          } else {
            _showToast('All pending beats in this track are already in focus!');
          }
        }
      },
      onRemoveFromFocus: (roadmap, beat) async {
        await _pacingService.removeBeatFromTodayFocus(roadmap.id, beat.id);
        await _loadDatabaseState();
        if (mounted) {
          _showToast('Removed "${beat.title}" from today\'s focus');
        }
      },
      onApplyPacingDecision: (roadmap, decision) async {
        await _pacingService.applyPacingDecision(roadmap.id, decision);
        await _loadDatabaseState();
        if (mounted) {
          final label = decision.type == PacingDecisionType.extendTargetDate
              ? 'Timeline extended by ${decision.extensionDays ?? 7} days'
              : (decision.type == PacingDecisionType.trimToCore
                  ? 'Deferred mentor extras to focus on core'
                  : (decision.type == PacingDecisionType.borrowSlack
                      ? 'Rebalanced pace across tracks'
                      : 'Pace accepted — rhythm preserved'));
          _showToast('Recalibrated: $label');
        }
      },
      inferenceService: _localInferenceService,
    );
  }

  Future<void> _openRoadmapDetail(RoadmapEntity roadmap) async {
    HapticFeedback.lightImpact();
    final chapters = _chaptersByRoadmap[roadmap.id] ?? [];
    final beats = _beatsByRoadmap[roadmap.id] ?? [];
    final todayMissionBeats = _budgetsByRoadmap[roadmap.id]?.todaysBeats ?? [];
    final todaysBeatIds = todayMissionBeats.map((b) => b.id).toSet();

    await Navigator.of(context).push(
      SmoothPageRoute(
        child: RoadmapDetailScreen(
          roadmap: roadmap,
          chapters: chapters,
          beats: beats,
          todaysBeatIds: todaysBeatIds,
          revisionShelfBeatIds: _allShelfItems.map((i) => i.beatId).toSet(),
          onMarkForRevision: _handleMarkForRevision,
          onBeatToggled: _setBeatCompletion,
          onToggleFocusBeat: (beat) async {
            final isInFocus = (_budgetsByRoadmap[roadmap.id]?.todaysBeats ?? [])
                .any((b) => b.id == beat.id);
            if (isInFocus) {
              await _pacingService.removeBeatFromTodayFocus(roadmap.id, beat.id);
              if (mounted) {
                _showToast('Removed "${beat.title}" from today\'s focus');
              }
            } else {
              await _pacingService.addBeatToTodayFocus(roadmap.id, beat.id);
              if (mounted) {
                _showToast('Added "${beat.title}" to today\'s focus');
              }
            }
            await _loadDatabaseState();
          },
          onArchiveRoadmap: _handleArchiveRoadmap,
          onRestoreRoadmap: _handleRestoreRoadmap,
          onDeleteRoadmap: _handleDeleteRoadmap,
          onAttachResource: _handleAttachResource,
          onAttachResourceToBeat: _handleAttachResourceToBeat,
          onSyncResource: _handleSyncResource,
          onSplitBeat: _handleSplitBeat,
          onIncrementBeatPart: _handleIncrementBeatPart,
          onDecrementBeatPart: _handleDecrementBeatPart,
          onUpdateTargetDate: _handleUpdateTargetDate,
          pacingBudget: _budgetsByRoadmap[roadmap.id],
        ),
      ),
    );
    if (mounted) {
      await _requestDatabaseReload();
    }
  }

  Future<void> _handleCreateTrack({
    required String title,
    required String category,
    DateTime? startDate,
    required DateTime targetDate,
    String? resourceUrl,
    String? syllabusText,
  }) async {
    if (syllabusText != null && syllabusText.trim().isNotEmpty) {
      final parsed = SyllabusParser.parse(syllabusText, defaultTitle: title);
      await _ingestionService.ingestFromSyllabus(
        title: title,
        category: category,
        startDate: startDate,
        targetDate: targetDate,
        syllabus: parsed,
        resourceUrl: resourceUrl,
      );
    } else if (resourceUrl != null && resourceUrl.isNotEmpty) {
      await _ingestionService.ingestFromUrl(
        url: resourceUrl,
        customRoadmapTitle: title,
        customDescription: category,
        startDate: startDate,
        targetCompletionDate: targetDate,
      );
    } else {
      final id = 'rm_${DateTime.now().millisecondsSinceEpoch}';
      final rm = RoadmapEntity(
        id: id,
        title: title,
        description: category,
        startDate: startDate ?? DateTime.now(),
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
      await _loadDatabaseState();
    }
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

  Future<void> _handleStartRoadmapEarly(RoadmapEntity roadmap) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final updated = roadmap.copyWith(startDate: today, updatedAt: now);
    await _roadmapRepo.updateRoadmap(updated);
    await _loadDatabaseState();
    if (mounted) {
      showGlassToast(
        context,
        'Kickoff updated to today! Daily to-do activated.',
        icon: Icons.bolt_rounded,
        accentColor: const Color(0xFF10B981),
      );
    }
  }

  Future<void> _handleDeleteRoadmap(RoadmapEntity roadmap) async {
    await _roadmapRepo.deleteRoadmap(roadmap.id);
    if (_roadmapId == roadmap.id) {
      _roadmapId = '';
    }
    await _loadDatabaseState();
    if (mounted) {
      showGlassToast(
        context,
        'Deleted "${roadmap.title}"',
        icon: Icons.delete_outline_rounded,
        accentColor: Colors.redAccent,
      );
    }
  }

  Future<void> _handleAttachResource(
    String roadmapId,
    String resourceUrl, {
    String? chapterId,
  }) async {
    try {
      if (chapterId != null) {
        await _ingestionService.attachResourceToSubject(
          roadmapId: roadmapId,
          chapterId: chapterId,
          resourceUrl: resourceUrl,
        );
      } else {
        await _ingestionService.attachResourceToRoadmap(
          roadmapId: roadmapId,
          resourceUrl: resourceUrl,
        );
      }
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

  Future<ResourceSyncResult> _handleSyncResource(
    RoadmapEntity roadmap, {
    String? overrideUrl,
  }) async {
    final result = await _resourceSyncService.syncRoadmapResource(
      roadmap: roadmap,
      overrideUrl: overrideUrl,
    );
    await _loadDatabaseState();
    return result;
  }

  Future<void> _enrichRestoredTracksInBackground() async {
    try {
      debugPrint('Starting post-restore YouTube playlist enrichment...');
      final results = await _resourceSyncService.syncAllRoadmaps();
      final updatedTracks = results
          .where((r) => r.success && (r.updatedBeatsCount > 0 || r.newBeatsCount > 0))
          .toList();
      if (mounted && updatedTracks.isNotEmpty) {
        await _loadDatabaseState();
        final totalUpdated = updatedTracks.fold(0, (sum, r) => sum + r.updatedBeatsCount);
        final totalNew = updatedTracks.fold(0, (sum, r) => sum + r.newBeatsCount);
        _showToast(
          'Synced with YouTube: refreshed $totalUpdated lessons'
          '${totalNew > 0 ? ', added $totalNew new videos' : ''} across ${updatedTracks.length} track${updatedTracks.length == 1 ? '' : 's'}',
        );
      }
    } catch (e) {
      debugPrint('Post-restore YouTube enrichment failed or offline: $e');
    }
  }

  Widget _buildExploreTab(RythemThemeColors themeColors, bool isDark) {
    return ExploreScreen(
      roadmaps: _allRoadmaps,
      chaptersByRoadmap: _chaptersByRoadmap,
      beatsByRoadmap: _beatsByRoadmap,
      onBeatToggled: _setBeatCompletion,
      onOpenRoadmapDetail: _openRoadmapDetail,
      onCreateTrack: _handleCreateTrack,
      onArchiveRoadmap: _handleArchiveRoadmap,
      onRestoreRoadmap: _handleRestoreRoadmap,
      onDeleteRoadmap: _handleDeleteRoadmap,
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
      beatLogRepo: _beatLogRepo,
      onOpenRoadmapDetail: _openRoadmapDetail,
    );
  }

  Widget _buildSettingsTab(RythemThemeColors themeColors, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    final currentDownload = _modelDownloadManager.downloadProgressNotifier.value;
    final isCompactDownloading = currentDownload?.tier == ModelTier.compact &&
        !(currentDownload?.isCompleted ?? true) &&
        currentDownload?.error == null;
    final isBalancedDownloading = currentDownload?.tier == ModelTier.balanced &&
        !(currentDownload?.isCompleted ?? true) &&
        currentDownload?.error == null;

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
          const SizedBox(height: 20),

          // 2. Liquid Glass Theme (Aurora, Cobalt, Solar, Studio)
          Text(
            'LIQUID GLASS THEME',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _buildThemePaletteSelector(themeColors, isDark),
          const SizedBox(height: 24),

          // 2. 7-Day Study Intensity & Daily Goals (Monday - Sunday)
          Text(
            '7-DAY STUDY INTENSITY & DAILY GOALS',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _buildStudyIntensityScheduleCard(themeColors, isDark),
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
                  isDownloading: isCompactDownloading,
                  themeColors: themeColors,
                  isDark: isDark,
                  onSelect: () => _handleSelectActiveModel(ModelTier.compact),
                  onDownload: isCompactDownloading ? null : () => _handleDownloadModel(ModelTier.compact),
                  onDelete: () => _handleDeleteModel(ModelTier.compact),
                ),
                _buildModelOptionTile(
                  info: ModelInfo.balanced,
                  isDownloaded: _balancedDownloaded,
                  isActive: _activeModelTier == ModelTier.balanced,
                  isDownloading: isBalancedDownloading,
                  themeColors: themeColors,
                  isDark: isDark,
                  onSelect: () => _handleSelectActiveModel(ModelTier.balanced),
                  onDownload: isBalancedDownloading ? null : () => _handleDownloadModel(ModelTier.balanced),
                  onDelete: () => _handleDeleteModel(ModelTier.balanced),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Data Backup & Restore
          Text(
            'DATA BACKUP & RESTORE',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          _buildAutoBackupCard(themeColors, isDark),
          const SizedBox(height: 12),
          _buildDataBackupCard(themeColors, isDark),
          const SizedBox(height: 24),

          // 5. Software Update
          Text(
            'SOFTWARE UPDATE',
            style: RythemTypography.labelSmall.copyWith(
              color: themeColors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          SoftwareUpdateCard(
            latestRelease: _latestReleaseInfo,
            isChecking: _isCheckingForUpdates,
            onCheckForUpdates: () => _handleCheckForUpdates(showToastIfUpToDate: true),
            onOpenUpdateModal: _handleOpenUpdateModal,
          ),
          const SizedBox(height: 24),

          // Quiet Version Metadata
          Center(
            child: Text(
              'Rythem • Local First • v${GithubReleaseService.currentAppVersion}',
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

  Widget _buildThemePaletteSelector(RythemThemeColors themeColors, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000),
        ),
      ),
      child: Row(
        children: ThemePalette.values.map((palette) {
          final isSelected = widget.themePalette == palette;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onThemePaletteChanged?.call(palette);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? palette.previewColors.first.withOpacity(0.18)
                          : palette.previewColors.first.withOpacity(0.12))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: palette.previewColors.first.withOpacity(isDark ? 0.45 : 0.35),
                          width: 1.0,
                        )
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: palette.previewColors.first.withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: palette.previewColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.previewColors.first.withOpacity(0.40),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      palette.displayName,
                      style: RythemTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudyIntensityScheduleCard(RythemThemeColors themeColors, bool isDark) {
    final days = [
      (1, 'Mon'),
      (2, 'Tue'),
      (3, 'Wed'),
      (4, 'Thu'),
      (5, 'Fri'),
      (6, 'Sat'),
      (7, 'Sun'),
    ];

    final totalTargetBeats = _weeklySchedule.totalWeeklyTargetBeats;
    final activeDays = _weeklySchedule.activeDaysCount;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Study Rhythm',
                style: RythemTypography.titleSmall.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                '$totalTargetBeats beats / wk',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any day to toggle intensity: Rest (0), Light (2), Normal (4), or Deep (6). Your daily pacing quota dynamically follows this schedule.',
            style: RythemTypography.bodySmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: days.map((d) {
              final weekday = d.$1;
              final dayLabel = d.$2;
              final intensity = _weeklySchedule.getIntensity(weekday);

              final (intensityColor, icon) = switch (intensity) {
                StudyIntensity.rest => (themeColors.textTertiary.withOpacity(0.5), Icons.bedtime_outlined),
                StudyIntensity.light => (const Color(0xFF64B5F6), Icons.wb_twilight_rounded),
                StudyIntensity.normal => (themeColors.textPrimary, Icons.auto_awesome_rounded),
                StudyIntensity.intense => (const Color(0xFFFF8A65), Icons.local_fire_department_rounded),
              };

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _cycleStudyIntensity(weekday),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayLabel,
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Icon(
                            icon,
                            size: 15,
                            color: intensityColor,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            intensity.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RythemTypography.labelSmall.copyWith(
                              color: intensityColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${intensity.targetBeats}b',
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0x10FFFFFF) : const Color(0x08000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active days: $activeDays/7',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
                Text(
                  'Daily avg: ${(totalTargetBeats / 7).toStringAsFixed(1)} beats',
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
    );
  }

  Widget _buildAutoBackupCard(RythemThemeColors themeColors, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Daily Auto-Backup',
                    style: RythemTypography.titleSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'On-Device',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: themeColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Automatically creates daily resilient snapshots to device storage, retaining 7 rolling days. Survives app cache wipes for instant disaster recovery.',
            style: RythemTypography.bodySmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColors.glassBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Auto-Backup',
                  style: TextStyle(
                    color: themeColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _latestAutoBackup != null
                      ? '${_latestAutoBackup!.relativeTimeDescription} (${_latestAutoBackup!.formattedSize})'
                      : 'Not run today',
                  style: TextStyle(
                    color: themeColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColors.glassBorder.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 13, color: themeColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _backupLocationDescription,
                    style: TextStyle(
                      color: themeColors.textTertiary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: _isPerformingAutoBackup ? null : _handleManualAutoBackup,
                  icon: Icons.sync_rounded,
                  label: _isPerformingAutoBackup ? 'Backing up...' : 'Back Up Now',
                  variant: GlassButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  onPressed: _handleRestoreAutoBackup,
                  icon: Icons.history_rounded,
                  label: 'Snapshots (${AutoBackupManager.maxRetainedDailySnapshots}d)',
                  variant: GlassButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataBackupCard(RythemThemeColors themeColors, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Data Portability & Backup',
                style: RythemTypography.titleSmall.copyWith(
                  color: themeColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Icon(
                Icons.shield_outlined,
                size: 16,
                color: themeColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Export your entire learning state (roadmaps, chapters, beats, streaks, logs, and settings) as a portable JSON file, or restore from a previous backup file.',
            style: RythemTypography.bodySmall.copyWith(
              color: themeColors.textTertiary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  onPressed: _handleExportBackup,
                  icon: Icons.file_upload_outlined,
                  label: 'Export Backup',
                  variant: GlassButtonVariant.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  onPressed: _handleImportBackup,
                  icon: Icons.file_download_outlined,
                  label: 'Restore Backup',
                  variant: GlassButtonVariant.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _cycleStudyIntensity(int weekday) async {
    HapticFeedback.selectionClick();
    final current = _weeklySchedule.getIntensity(weekday);
    final next = switch (current) {
      StudyIntensity.rest => StudyIntensity.light,
      StudyIntensity.light => StudyIntensity.normal,
      StudyIntensity.normal => StudyIntensity.intense,
      StudyIntensity.intense => StudyIntensity.rest,
    };
    final updated = _weeklySchedule.withIntensity(weekday, next);
    setState(() => _weeklySchedule = updated);
    await _appSettingsRepo.setSetting('study_intensity_schedule', updated.encode());
    await _loadDatabaseState();
    _showToast('${WeeklyStudySchedule.dayName(weekday)} set to ${next.label} (${next.targetBeats} beats)');
  }

  Future<void> _handleCheckForUpdates({bool showToastIfUpToDate = true}) async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);
    HapticFeedback.lightImpact();

    try {
      final info = await _githubReleaseService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _latestReleaseInfo = info;
        _isCheckingForUpdates = false;
      });

      if (info.isUpdateAvailable) {
        UpdateModalSheet.show(
          context,
          releaseInfo: info,
          releaseService: _githubReleaseService,
          installerService: _nativeInstallerService,
        );
      } else if (showToastIfUpToDate) {
        _showToast("You're on the latest version of Rythem (${info.currentVersion.displayTag})");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingForUpdates = false);
      _showToast('Update check failed: $e');
    }
  }

  void _handleOpenUpdateModal() {
    final info = _latestReleaseInfo;
    if (info != null) {
      UpdateModalSheet.show(
        context,
        releaseInfo: info,
        releaseService: _githubReleaseService,
        installerService: _nativeInstallerService,
      );
    }
  }

  Future<void> _handleExportBackup() async {
    HapticFeedback.mediumImpact();
    try {
      final file = await _backupService.exportToFile();
      if (file == null) {
        _showToast('Export cancelled');
        return;
      }
      final name = file.path.split('/').last;
      _showToast('Backup exported: $name');
    } catch (e) {
      _showToast('Export failed: $e');
    }
  }

  Future<void> _handleManualAutoBackup() async {
    if (_isPerformingAutoBackup) return;
    setState(() => _isPerformingAutoBackup = true);
    HapticFeedback.mediumImpact();
    try {
      final info = await _autoBackupManager.checkAndPerformDailyBackup(force: true);
      final location = await _autoBackupManager.getStorageLocationDescription();
      if (mounted) {
        setState(() {
          _latestAutoBackup = info;
          _backupLocationDescription = location;
          _isPerformingAutoBackup = false;
        });
        if (info != null) {
          _showToast('Backup saved to $location (${info.formattedSize})');
        } else {
          _showToast('Backup completed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPerformingAutoBackup = false);
        _showToast('Backup failed: $e');
      }
    }
  }

  Future<void> _handleRestoreAutoBackup() async {
    final backups = await _autoBackupManager.listAvailableBackups();
    if (!mounted) return;
    if (backups.isEmpty) {
      _showToast('No auto-backups found on this device');
      return;
    }

    final selected = await showModalBottomSheet<BackupSnapshotInfo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final colors = isDark ? RythemColors.dark : RythemColors.light;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE6141418) : const Color(0xF5F7F7FA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: colors.glassBorder),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 20, color: colors.actionPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'Select Auto-Backup Snapshot',
                      style: RythemTypography.titleMedium.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a rolling daily snapshot stored locally in device storage to restore.',
                  style: RythemTypography.bodySmall.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: backups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = backups[index];
                      final isLatest = item.fileName == AutoBackupManager.latestBackupFileName;
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, item),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: colors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.actionPrimary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isLatest ? Icons.star_rounded : Icons.backup_outlined,
                                  size: 18,
                                  color: colors.actionPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.displayTitle,
                                            style: RythemTypography.titleSmall.copyWith(
                                              color: colors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${item.relativeTimeDescription}',
                                          style: RythemTypography.labelSmall.copyWith(
                                            color: colors.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.roadmapsCount} tracks • ${item.beatsCount} beats • ${item.formattedSize}',
                                      style: RythemTypography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textTertiary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;
          final colors = isDark ? RythemColors.dark : RythemColors.light;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Restore This Snapshot?',
              style: RythemTypography.titleMedium.copyWith(color: colors.textPrimary),
            ),
            content: Text(
              'Restoring "${selected.displayTitle}" (${selected.relativeTimeDescription}) will replace current database state with this snapshot\'s data.\n\nProceed?',
              style: RythemTypography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: colors.textTertiary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.actionPrimary,
                  foregroundColor: colors.actionOnPrimary,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Restore'),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        HapticFeedback.heavyImpact();
        try {
          await _autoBackupManager.restoreSnapshot(selected.file);
          await _loadDatabaseState();
          _showToast('Restored from "${selected.displayTitle}"! 🎉');
          unawaited(_enrichRestoredTracksInBackground());
        } catch (e) {
          _showToast('Restore error: $e');
        }
      }
    }
  }

  Future<void> _checkDisasterRecovery() async {
    if (!mounted) return;
    try {
      final recoverySnapshot = await _autoBackupManager.checkForDisasterRecovery();
      if (recoverySnapshot != null && mounted) {
        _showDisasterRecoveryDialog(recoverySnapshot);
      }
    } catch (e) {
      debugPrint('Disaster recovery check error: $e');
    }
  }

  Future<void> _showDisasterRecoveryDialog(BackupSnapshotInfo snapshot) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final colors = isDark ? RythemColors.dark : RythemColors.light;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.settings_backup_restore, color: colors.actionPrimary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Restore Previous Data?',
                  style: RythemTypography.titleMedium.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No active tracks were found, but we discovered a local auto-backup from ${snapshot.relativeTimeDescription}.',
                style: RythemTypography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? colors.glassBorder : const Color(0x14000000),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tracks / Roadmaps', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                        Text('${snapshot.roadmapsCount}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Beats', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                        Text('${snapshot.beatsCount}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Activity & Streaks', style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                        Text('${snapshot.logsCount} logs', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Would you like to restore this backup to resume your learning?',
                style: RythemTypography.bodySmall.copyWith(color: colors.textTertiary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Start Fresh', style: TextStyle(color: colors.textTertiary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.actionPrimary,
                foregroundColor: colors.actionOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Backup'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _autoBackupManager.restoreSnapshot(snapshot.file);
        await _loadDatabaseState();
        _showToast('Restored successfully from auto-backup! 🎉');
        unawaited(_enrichRestoredTracksInBackground());
      } catch (e) {
        _showToast('Failed to restore auto-backup: $e');
      }
    }
  }

  Future<void> _handleImportBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final colors = isDark ? RythemColors.dark : RythemColors.light;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Restore Data Backup',
            style: RythemTypography.titleMedium.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'Restoring a backup will replace your current tracks, chapters, beats, streak history, and settings with the contents of the backup file.\n\nDo you want to proceed?',
            style: RythemTypography.bodyMedium.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: colors.textTertiary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.actionPrimary,
                foregroundColor: colors.actionOnPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Select File & Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    HapticFeedback.heavyImpact();
    try {
      final success = await _backupService.pickAndRestoreBackup();
      if (success != null) {
        await _loadDatabaseState();
        _showToast('Backup successfully restored!');
        unawaited(_enrichRestoredTracksInBackground());
      } else {
        _showToast('Restore cancelled or failed');
      }
    } catch (e) {
      _showToast('Restore failed: $e');
    }
  }

  Widget _buildModelOptionTile({
    required ModelInfo info,
    required bool isDownloaded,
    required bool isActive,
    bool isDownloading = false,
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
                onTap: (info.tier == ModelTier.fallback || isDownloaded)
                    ? onSelect
                    : (isDownloading ? null : onDownload),
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
                if (isDownloading)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(themeColors.textPrimary),
                      ),
                    ),
                  )
                else if (!isDownloaded)
                  GestureDetector(
                    onTap: onDownload,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.download_rounded,
                        size: 17,
                        color: themeColors.textPrimary,
                      ),
                    ),
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

