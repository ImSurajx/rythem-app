# Rythem Codebase Blueprint & Feature Implementation Map

> **Agent Reference**: Comprehensive architectural blueprint, module directory, state flow lifecycle, and feature-to-file change matrix. Consult this map before modifying any part of the Rythem application to immediately identify which files to inspect, modify, or extend.

---

## 1. System Architecture & Component Hierarchy

Rythem is a 100% offline-first, local-first learning operating system built with Flutter and Dart. All application state is stored locally in embedded SQLite, and on-device SLMs (Qwen 2.5 GGUF) provide private pedagogy and pacing recommendations.

```
lib/
├── main.dart                          # Application Entry, Root State Shell, Tab Navigation & In-Flight Sync
├── core/                              # Shared Kernel, Infrastructure, & Data Layer
│   ├── ai/                            # Local On-Device AI & Pedagogy
│   │   ├── ai.dart                    # Barrel export
│   │   ├── models/
│   │   │   ├── model_tier.dart        # ModelTier enum (fallback, compact 0.5B, balanced 1.5B), ModelInfo
│   │   │   └── curriculum_audit_result.dart # CurriculumAuditResult, TopicGap, VideoAlignment
│   │   └── services/
│   │       ├── local_inference_service.dart # Concept queries, ShortfallDiagnosis, topic similarity
│   │       └── model_download_manager.dart  # Resumable GGUF downloader from GitHub releases
│   ├── backup/                        # JSON Data Backup & Restoration
│   │   └── services/
│   │       └── backup_service.dart    # Full SQLite export/import, file picking, validation
│   ├── database/                      # SQLite Persistence Layer
│   │   ├── database.dart              # Barrel export
│   │   ├── database_service.dart      # Singleton SQLite lifecycle, PRAGMA foreign_keys, migrations
│   │   ├── database_event_bus.dart    # Reactive Stream event bus for DB mutations
│   │   ├── tables.dart                # DatabaseTables & Column schema definitions
│   │   ├── models/                    # Data Entities
│   │   │   ├── roadmap_entity.dart    # RoadmapEntity (Curriculum track)
│   │   │   ├── chapter_entity.dart    # ChapterEntity (Grouping milestone with sort_order)
│   │   │   ├── beat_entity.dart       # BeatEntity (Atomic task/video/exercise with effort weight)
│   │   │   ├── beat_log_entity.dart   # BeatLogEntity (Historical completion log for streaks)
│   │   │   ├── app_settings_entity.dart # AppSettingEntity (Key-value app state)
│   │   │   └── models.dart            # Barrel export
│   │   └── repositories/              # Specialized Repositories
│   │       ├── roadmap_repository.dart
│   │       ├── chapter_repository.dart
│   │       ├── beat_repository.dart
│   │       ├── beat_log_repository.dart
│   │       ├── app_settings_repository.dart
│   │       └── repositories.dart
│   ├── ingestion/                     # Playlist & Markdown Parsing & Alignment
│   │   ├── ingestion.dart             # Barrel export
│   │   ├── models/                    # ExtractedResource, ExtractedChapter, ExtractedBeat, IngestionResult, SyllabusTopic
│   │   ├── parsers/
│   │   │   ├── chapter_clusterer.dart # Clusters flat video lists into 4-8 logical chapters
│   │   │   ├── effort_weight_calculator.dart # Maps video durations to effort weights (0.5 - 3.0)
│   │   │   ├── syllabus_parser.dart   # Parses raw markdown outlines into structured syllabus topics
│   │   │   └── timestamp_parser.dart  # Extracts timestamps and video links
│   │   └── services/
│   │       ├── curriculum_ingestion_service.dart # Transactional coordinator for roadmaps/chapters/beats
│   │       ├── syllabus_matcher_service.dart     # Semantic topic matcher; flags mentor extras
│   │       └── youtube_extractor_service.dart    # YoutubeExplode wrapper for playlists and videos
│   ├── navigation/
│   │   └── smooth_page_route.dart     # Platform-tuned fluid screen transitions
│   ├── pacing/                        # Mathematical Pacing & Backlog Dilution Engine
│   │   ├── pacing.dart                # Barrel export
│   │   ├── models/
│   │   │   ├── pacing_budget.dart     # PacingBudget (daily effort, lag streaks, velocity)
│   │   │   ├── pacing_decision.dart   # Recalibration actions (extend, trim, borrow, accept)
│   │   │   └── study_intensity.dart   # Rest (0), Light (2), Normal (4), Intense (6), WeeklyStudySchedule
│   │   └── services/
│   │       ├── pacing_service.dart    # DB-aware budget orchestrator & decision applier
│   │       └── pacing_calculator.dart # Pure deterministic math (days left, queue walker, trend)
│   ├── revision/                      # Ebbinghaus Spaced Repetition Engine
│   │   ├── models/
│   │   │   └── revision_item.dart     # RevisionItem (retention score, stability days, flags)
│   │   └── services/
│   │       └── revision_service.dart  # Forgetting curve calculations, weak concept flagging
│   ├── theme/                         # Liquid Glass Design System Tokens
│   │   ├── colors.dart                # RythemColors (Pitch black dark mode & Apple frosted light mode)
│   │   ├── typography.dart            # RythemTypography (Inter typography scale)
│   │   └── theme.dart                 # ThemeData builders for dark & light modes
│   ├── utils/
│   │   └── resource_launcher.dart     # External URL & video deep-linking utilities
│   └── widgets/                       # Reusable Liquid Glass UI Components
│       ├── widgets.dart               # Barrel export
│       ├── glass_card.dart            # Tactile frosted glass container with specular borders
│       ├── glass_button.dart          # Primary, secondary, outline, and destructive glass buttons
│       ├── glass_progress_bar.dart    # Segmented and continuous specular progress indicators
│       ├── glass_toast.dart           # Ambient non-intrusive bottom glass toasts
│       ├── glass_container.dart       # Backdrop-filtered surface container
│       ├── glass_bottom_dock.dart     # Floating 4-item navigation dock with spring animations
│       ├── glass_error_dialog.dart    # Frosted alert and recovery dialog
│       ├── fade_indexed_stack.dart    # Zero-lag tab switcher preserving scroll states
│       └── markdown_content_view.dart # Custom-styled markdown renderer
│
└── features/                          # Domain Feature Screens & Components
    ├── flow/                          # Daily Focus & Active Learning Hub (Tab 0)
    │   ├── flow_screen.dart           # Daily mission, streak banner, track filter, whole todo list
    │   ├── confusing_beat_dialog.dart # AI clarification prompt & explanation modal
    │   ├── session_detail_screen.dart # Distraction-free focus mode with notes & resource launcher
    │   └── widgets/
    │       ├── backlog_decision_sheet.dart # Non-punitive recalibration dialog for sustained lag
    │       └── daily_revision_board.dart   # Interactive spaced-repetition revision cards
    ├── explore/                       # Track Catalog & Ingestion (Tab 1)
    │   ├── explore_screen.dart        # Searchable track list, progress stats, delete/archive
    │   ├── new_track_modal.dart       # Modal to create track via YouTube URL or Markdown outline
    │   ├── roadmap_detail_screen.dart # Deep chapter accordion view, beat toggles, resource linker
    │   └── widgets/
    │       └── chapter_accordion.dart # Collapsible chapter card with beat checkboxes & mentor badges
    ├── metrics/                       # Velocity & Habit Analytics (Tab 2)
    │   ├── metrics_screen.dart        # Lifetime beat totals, velocity, roadmap progress summaries
    │   └── widgets/
    │       ├── full_month_streak_calendar.dart # Full calendar grid with interactive day inspection
    │       └── performance_graphs_card.dart    # Multi-mode bar/line charts for study activity
    └── onboarding/                    # First-Run Calibration & Setup
        └── onboarding_wizard_screen.dart # 4-step wizard: philosophy, dilution, AI download, cadence
```

---

## 2. Core State Flows & Event Lifecycle

### A. Root State Management (`lib/main.dart`)
- **Primary Shell State**: `_DesignSystemShowcaseScreenState` in `lib/main.dart` is the single source of truth for in-memory data:
  - `_allRoadmaps`: List of active and archived tracks.
  - `_chaptersByRoadmap`: Map of `roadmapId -> List<ChapterEntity>`.
  - `_beatsByRoadmap`: Map of `roadmapId -> List<BeatEntity>`.
  - `_budgetsByRoadmap`: Map of `roadmapId -> PacingBudget`.
  - `_delayedBeatIds`: Set of beat IDs deferred for later review.
  - `_revisionItems`: Spaced-repetition items scheduled for today.
  - `_currentTabIndex`: 0 (Flow), 1 (Explore), 2 (Metrics), 3 (Settings).
- **Navigation Dock**: Rendered inside an `IndexedStack` / `FadeIndexedStack` so changing tabs never unmounts widgets or drops scroll positions.

### B. In-Flight Beat Toggle Synchronization
To prevent race conditions and screen flickering between Flow and Explore:
1. User taps beat checkbox -> optimistic local state update (`setState()`).
2. Beat ID registered in `_pendingBeatToggles[beatId]`.
3. Sequential async write via `_lastToggleOperation` -> `BeatRepository.toggleBeatCompletion()`.
4. Debounced reload timer (`_scheduleDebouncedReload(80ms)`) triggers `_requestDatabaseReload()`.
5. SQLite state is read fresh and merged with any remaining pending toggles.
6. `PacingBudget` is recomputed via `PacingService` and broadcast to all tabs simultaneously.

### C. Database Event Bus (`lib/core/database/database_event_bus.dart`)
- Repositories emit `DatabaseEvent` (`roadmapCreated`, `roadmapUpdated`, `beatToggled`, etc.) over a broadcast stream.
- Active screens (such as `RoadmapDetailScreen`) subscribe to `DatabaseEventBus.instance.stream` to trigger local re-queries when changes occur elsewhere.

---

## 3. Feature-to-File Change Matrix

When you receive a request to modify or implement a feature, use this table to immediately identify the exact files to alter:

| Feature Area | User Action / Requirement | Primary Files to Modify | Supporting / Reference Files |
| :--- | :--- | :--- | :--- |
| **Flow & Daily Todos** | Add new todo filtering, group display, or change daily mission card layout | [`lib/features/flow/flow_screen.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/flow_screen.dart) | [`lib/main.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart), [`lib/core/widgets/glass_card.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/widgets/glass_card.dart) |
| **Beat Checkbox & Toggle** | Change beat completion behavior, add notes, or adjust in-flight synchronization | [`lib/main.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart) (`_setBeatCompletion`), [`lib/core/database/repositories/beat_repository.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/beat_repository.dart) | [`lib/features/explore/widgets/chapter_accordion.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/widgets/chapter_accordion.dart) |
| **Pacing & Quotas** | Modify daily effort share calculation, dynamic dilution formula, or 7-day schedule | [`lib/core/pacing/services/pacing_calculator.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/services/pacing_calculator.dart), [`lib/core/pacing/services/pacing_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/services/pacing_service.dart) | [`lib/core/pacing/models/pacing_budget.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/models/pacing_budget.dart), [`lib/core/pacing/models/study_intensity.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/models/study_intensity.dart) |
| **Backlog & Lag Recalibration** | Change 3-day shortfall detection, recalibration options, or banner UI | [`lib/features/flow/widgets/backlog_decision_sheet.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/widgets/backlog_decision_sheet.dart), [`lib/core/ai/services/local_inference_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ai/services/local_inference_service.dart) (`diagnoseShortfallAndRecommend`) | [`lib/core/pacing/models/pacing_decision.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/models/pacing_decision.dart) |
| **Curriculum Ingestion** | Support new syllabus formats, alter YouTube video extraction, or adjust chapter clustering | [`lib/core/ingestion/parsers/syllabus_parser.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ingestion/parsers/syllabus_parser.dart), [`lib/core/ingestion/parsers/chapter_clusterer.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ingestion/parsers/chapter_clusterer.dart), [`lib/core/ingestion/services/curriculum_ingestion_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ingestion/services/curriculum_ingestion_service.dart) | [`lib/features/explore/new_track_modal.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/new_track_modal.dart), [`lib/core/ingestion/services/youtube_extractor_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ingestion/services/youtube_extractor_service.dart) |
| **Track Management** | Add/edit/archive/delete roadmaps or chapter accordions | [`lib/features/explore/explore_screen.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/explore_screen.dart), [`lib/features/explore/roadmap_detail_screen.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/roadmap_detail_screen.dart) | [`lib/core/database/repositories/roadmap_repository.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/roadmap_repository.dart), [`lib/core/database/repositories/chapter_repository.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/chapter_repository.dart) |
| **Spaced Repetition & Revision** | Adjust Ebbinghaus decay curve, weak concept flagging, or revision card UI | [`lib/core/revision/services/revision_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/revision/services/revision_service.dart), [`lib/features/flow/widgets/daily_revision_board.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/widgets/daily_revision_board.dart) | [`lib/core/revision/models/revision_item.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/revision/models/revision_item.dart) |
| **Local AI & SLM Inference** | Modify AI prompt handling, concept explanations, or model download management | [`lib/core/ai/services/local_inference_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ai/services/local_inference_service.dart), [`lib/core/ai/services/model_download_manager.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ai/services/model_download_manager.dart) | [`lib/features/flow/confusing_beat_dialog.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/confusing_beat_dialog.dart), [`lib/core/ai/models/model_tier.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/ai/models/model_tier.dart) |
| **Metrics & Analytics** | Add new charts, modify streak calculations, or change calendar view | [`lib/features/metrics/metrics_screen.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/metrics/metrics_screen.dart), [`lib/features/metrics/widgets/performance_graphs_card.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/metrics/widgets/performance_graphs_card.dart), [`lib/features/metrics/widgets/full_month_streak_calendar.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/metrics/widgets/full_month_streak_calendar.dart) | [`lib/core/database/repositories/beat_log_repository.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/beat_log_repository.dart) |
| **Settings & Appearance** | Add settings options, modify dark/light theme tokens, or adjust backup/restore | [`lib/main.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart) (`_buildSettingsTab`), [`lib/core/theme/colors.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/theme/colors.dart), [`lib/core/backup/services/backup_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/backup/services/backup_service.dart) | [`lib/core/database/repositories/app_settings_repository.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/app_settings_repository.dart) |
| **Onboarding Flow** | Adjust onboarding slides, calibration parameters, or first-run experience | [`lib/features/onboarding/onboarding_wizard_screen.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/features/onboarding/onboarding_wizard_screen.dart) | [`lib/main.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart) (`_checkOnboarding`) |
| **Database Schema & Migrations** | Add tables, columns, or migration logic | [`lib/core/database/tables.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/tables.dart), [`lib/core/database/database_service.dart`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/database_service.dart) | Corresponding Entity in `lib/core/database/models/` and Repository in `lib/core/database/repositories/` |

---

## 4. Key Architectural Invariants & Rules

1. **Zero Raw SQL in UI Widgets**: Always route database access through dedicated repositories in [`lib/core/database/repositories/`](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/).
2. **Zero Mock/Fake Data in Production**: Never inject sample roadmaps or dummy streaks into production initialization. Clean installs start with 0 roadmaps, 0 beats, and 0d streak.
3. **Mentor's Chronological Flow Is Ground Truth**: Ingestion and queue walking must preserve creator sequence. Items outside an external syllabus are tagged `is_mentor_extra: true`, never dropped.
4. **No Clocks or Timers**: Do not introduce minute countdowns or stopwatches. Progress is strictly measured in completed beats and effort weights ($W_i \in [0.5, 3.0]$).
5. **Liquid Glass Aesthetic & Rendering Constraints**:
   - Wrap heavy custom painters or static blur elements in `RepaintBoundary`.
   - Never put `BackdropFilter` inside scrolling ListView items.
   - All components must provide high contrast support in both `RythemColors.dark` and `RythemColors.light`.
6. **Git Sign-Off**: Always commit using `git commit -s`.
7. **Production AI Weights Tag**: The GitHub release `models-v1.0.0` hosts production GGUF weights. Never delete this tag or release.
