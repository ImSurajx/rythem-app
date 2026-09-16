# Rythem Architecture & System Blueprint

> **For AI Agents & Developers**: This document provides a complete technical guide to Rythem's codebase architecture, data pipelines, reactive event loops, folder structure, and module interconnections. Read this before modifying features or refactoring code.

---

## 1. System Identity & Core Philosophy

Rythem is an offline-first, local-first learning operating system built with Flutter and Dart. Its design is governed by strict core principles:

1. **"Beats Over Clocks" ("Felt, Not Measured")**:
   - Zero stopwatches, timers, or toxic countdown banners.
   - The atomic unit of progress is a **Beat** (a milestone, video lesson, chapter section, or exercise).
   - Progress is measured purely in completed beats and effort weights ($W_i \in [0.5, 3.0]$).

2. **Dynamic Pacing Dilution**:
   - Mathematical redistribution of effort rather than aggressive guilt-inducing warnings.
   - When a user misses days, remaining effort is gently smoothed across remaining calendar days.
   - Daily mission quotas follow a configurable 7-day study intensity schedule (Rest, Light, Normal, Deep).

3. **Mentor's Flow Is King**:
   - Chronological teaching order of creator playlists is ground truth.
   - When aligned with an external syllabus, non-syllabus topics covered by the mentor are preserved in-place and marked `mentor_extra: true`, never deleted or relegated to an orphaned bin.

4. **Monochrome Frosted Glass Aesthetics & Fluid 60/120 FPS Rendering**:
   - Fluid liquid glassmorphism (specular highlights, subtle borders, ambient translucency).
   - State preservation across tabs using `FadeIndexedStack`.
   - Backdrop filters are isolated inside `RepaintBoundary` widgets and avoided on moving scrollable surfaces to eliminate dropped frames.

5. **Offline-First & Private Intelligence**:
   - All core databases run on embedded SQLite (`sqflite`).
   - Private on-device SLMs (Small Language Models: Qwen 2.5 0.5B and 1.5B GGUF) run local inference for concept explanations and shortfall root cause analysis.
   - Zero cloud subscriptions or external telemetry required for core operation.

---

## 2. Directory Hierarchy & Module Linking

The codebase is organized into a modular, clean-architecture structure under `lib/`:

```
lib/
├── core/                         # Shared kernel & infrastructure
│   ├── ai/                       # Local inference, models & background downloader
│   │   ├── models/               # ModelTier, DownloadProgress, GGUF metadata
│   │   └── services/             # LocalInferenceService, ModelDownloadManager
│   ├── database/                 # SQLite persistence & data access layer
│   │   ├── models/               # Entities (Roadmap, Chapter, Beat, BeatLog, AppSetting)
│   │   ├── repositories/         # Specialized repositories with SQL queries
│   │   ├── database_service.dart # Singleton SQLite database lifecycle & migrations
│   │   └── tables.dart           # Database table & column schema constants
│   ├── pacing/                   # Mathematical pacing & scheduling engine
│   │   ├── models/               # PacingBudget, StudyIntensity, WeeklyStudySchedule
│   │   └── services/             # PacingService (dilution, quota calculations)
│   ├── theme/                    # Design system tokens & typography
│   │   ├── colors.dart           # RythemColors (dark/light tokens, frosted glass borders)
│   │   ├── typography.dart       # RythemTypography (Inter font scales)
│   │   └── theme.dart            # ThemeData builders for dark & light modes
│   └── widgets/                  # Reusable liquid glass UI components
│       ├── glass_card.dart       # Tactile glass container with specular borders
│       ├── glass_progress_bar.dart# Translucent segmented & continuous progress bars
│       ├── glass_toast.dart      # Non-intrusive ambient status toasts
│       └── glass_text_field.dart # Frosted input fields
│
├── features/                     # Feature modules (Domain-driven screens & widgets)
│   ├── flow/                     # Daily Focus & Active Learning Hub
│   │   ├── flow_screen.dart      # Main Todo screen: Daily mission, backlog sheet, streak
│   │   └── widgets/              # Daily revision board, backlog decision modal, lag banner
│   ├── explore/                  # Curriculum Catalog & Ingestion
│   │   ├── explore_screen.dart   # Roadmap catalog & syllabus / playlist ingestion triggers
│   │   ├── roadmap_detail_screen.dart # Chapter accordion, beat list, resource linker
│   │   └── widgets/              # Syllabus ingestion sheet, mentor alignment cards
│   ├── metrics/                  # Progress, Velocity & Habit Analytics
│   │   ├── metrics_screen.dart   # Dashboard: completed beats, velocity, active tracks
│   │   └── widgets/              # FullMonthStreakCalendar, PerformanceGraphsCard
│   └── onboarding/               # First-Run Setup & Calibration
│       └── onboarding_wizard_screen.dart # Study rhythm calibration, AI model selection
│
└── main.dart                     # Application shell, tab navigation & in-flight pipeline
```

---

## 3. Data Pipelines & Event Loops

### A. The Beat Toggle & Real-Time Sync Pipeline

To eliminate race conditions between the **Flow (Todo)** tab and the **Explore (Tracker)** tab:

```
[User Taps Beat Checkbox on Flow or Explore]
                     │
                     ▼
    1. Optimistic UI State Update (Immediate visual response)
                     │
                     ▼
    2. Register in In-Flight Registry (_pendingBeatToggles[beatId] = isCompleted)
                     │
                     ▼
    3. Persist to SQLite via BeatRepository.toggleBeatCompletion()
       - Updates beats.is_completed & completed_at
       - Inserts or removes row in beat_logs table
                     │
                     ▼
    4. Debounced Schedule Reload (_scheduleDebouncedReload(80ms))
       - Waits for burst clicks to settle
       - Reads fresh records from SQLite
       - Overlays _pendingBeatToggles to prevent read-clobbering
       - Recomputes PacingBudget via PacingService
       - Notifies FlowScreen, ExploreScreen, and MetricsScreen simultaneously
```

### B. The Curriculum Ingestion Pipeline

Ingesting YouTube playlists or Markdown syllabi:

```
[User Submits YouTube Playlist URL or Raw Syllabus Markdown]
                     │
                     ▼
    ExploreScreen -> SyllabusIngestionSheet
                     │
                     ▼
    1. Extraction Phase
       - YouTube: youtube_explode_dart extracts video titles, durations, URLs.
       - Markdown: Outline parser extracts headings, topics, and subtopics.
                     │
                     ▼
    2. Semantic Clustering & Chaptering
       - Local AI (Qwen 2.5) or heuristic NLP clusters items into 4-8 logical chapters.
       - Matches topics against syllabus outline (if present).
       - Items outside the syllabus are tagged `mentor_extra: true`.
                     │
                     ▼
    3. Database Persistence (Transactional Batch)
       - RoadmapEntity inserted into `roadmaps`
       - ChapterEntities inserted into `chapters` (with sortOrder)
       - BeatEntities inserted into `beats` (with effortWeight and resource links)
                     │
                     ▼
    4. Immediate Shell State Refresh
       - Main shell switches active roadmap to the newly ingested track.
```

### C. The Pacing & Dilution Pipeline

The mathematical pacing engine runs on demand without cloud dependencies:

```
PacingService.computePacingBudget(roadmapId)
  │
  ├── 1. Query all non-completed beats: Effort remaining = Sum(beat.effortWeight)
  ├── 2. Calculate remaining calendar days = max(1, targetDate.difference(now).inDays)
  ├── 3. Read 7-day study intensity for today (WeeklyStudySchedule: 0, 2, 4, or 6 beats)
  ├── 4. Apply Dynamic Dilution:
  │      dailyShare = (effortRemaining / remainingDays) * (intensityMultiplier)
  ├── 5. Determine today's mission beat candidates:
  │      Select top uncompleted beats matching todayShare
  └── 6. Return immutable PacingBudget:
         - todayEffortShare
         - todaysSelectedEffort
         - remainingEffort
         - isDailyQuotaCompleted
         - lagStreakDays (consecutive days behind schedule)
         - isSustainedLag (true if lagStreakDays >= 3)
```

### D. Offline Local Intelligence Pipeline

Private on-device AI mentorship:

```
LocalInferenceService
  ├── ModelTier: compact (Qwen 2.5 0.5B ~468MB) | balanced (Qwen 2.5 1.5B ~1.04GB)
  ├── Storage: Saved locally in DocumentsDirectory/models/
  ├── Engine:
  │    - Production: On-device GGUF runtime / CoreML / NNAPI
  │    - Fallback: Deterministic pedagogical heuristic engine
  └── Tasks:
       - Concept Explanations: Explains difficult beats in plain language.
       - Shortfall Remediation: Analyzes backlog accumulation and recommends recovery pacing.
       - Revision Engine: Spaced repetition queries with active recall prompts.
```

---

## 4. Key Architectural Contracts & Rules

When extending or maintaining this codebase, observe the following rules:

1. **Zero Sample / Predefined Mock Data**:
   - The app must initialize in a clean state.
   - Fresh installs have `0` roadmaps, `0` beats, `0d streak`, and `0` 7-day activity.
   - Never reintroduce hardcoded sample roadmaps (`rm_demo`), synthetic revision items, or fake streak day injectors.

2. **Clean SQLite Foreign Keys & Cascading**:
   - `PRAGMA foreign_keys = ON;` is strictly enforced.
   - When a roadmap is deleted, all associated chapters, beats, and beat logs are automatically cascade-deleted.
   - If `roadmaps` is empty, `beat_logs` must remain empty.

3. **Signed Git Commits (`git commit -s`)**:
   - Every commit must include the `-s` sign-off flag.

4. **Uniform Versioning Across Project**:
   - Update `pubspec.yaml` (`version: X.Y.Z+build`).
   - Maintain [CHANGELOG.md](file:///Users/itsurajx/Developer/rythem-app/CHANGELOG.md) with detailed markdown notes for every version.
   - CI release workflow (`.github/workflows/build-apk.yml`) reads directly from `CHANGELOG.md` (`--notes-file CHANGELOG.md`).

5. **Preserve `models-v1.0.0` GitHub Release**:
   - The release tag `models-v1.0.0` hosts production GGUF AI weights used by `ModelDownloadManager`. **NEVER delete this release or tag.**
