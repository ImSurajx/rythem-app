# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2-pre.1] - 2026-10-01

### Added
- **Effort Points System (1 Effort Point = 10 Minutes)**:
  - Replaced raw beat counts with meaningful, time-scaled Effort Points throughout the entire application.
  - Standalone video chapter effort calculation: dynamically computes exact chapter effort points using timestamp deltas `(nextChapterTimestamp - currentChapterTimestamp) / 10 min` (or `(videoDuration - currentChapterTimestamp) / 10 min` for the final chapter).
  - Playlist video duration remapping with fast batch processing and duration normalization.
  - Proportional effort point allocation for partial checkpoints (25%, 50%, 75%, 100%).
  - 7-day metric performance graphs and calendar tiles display actual daily effort points instead of arbitrary beat counts.
- **Flag Notes Notebook & Exploration Hub**:
  - Dedicated "Flag Notes" notebook tab in Explore with search, tag filters, and inline note previews.
  - One-tap navigation from a flagged note directly into its roadmap and chapter context.
- **Fluid Motion Design System & Micro-Animations**:
  - Smooth page navigation transitions with cross-fading via `SharedAxisTransition` / `PageTransitionSwitcher`.
  - Global iOS/macOS-style `BouncingScrollPhysics` across all screens for silky, responsive scrolling.
  - Interactive frosted glass dialogs with smooth entry and exit scaling/fading (`SmoothDialog`).
  - Integrated `flutter_animate` with test-safe central configuration (`RythemMotion`), floating dock rebounds, and staggered card entrances.
- **User-Driven Focus Topic Selection**:
  - Replaced rigid automated queue generation with self-paced topic pulling ("Focus Next" or pull directly into Today's Focus).
  - Completed topics remain permanently visible in Today's Focus with strike-through styling and instant 1-tap Undo toast protection.
- **Multi-Playlist & Resource Synchronization**:
  - Background resource synchronization engine that auto-refreshes video durations, metadata, and timestamps without freezing or timing out.
  - Preserves source playlist URLs with `list` query parameters on fresh tracker creation.
- **Comprehensive QA Release Testing Guide**:
  - Added full end-to-end testing and QA documentation in `docs/release_testing_guide.md`.

### Changed
- **Decoupled Flags from Progress Checkpoints**:
  - Completely separated Flag Notes (doubts, confusion points, conceptual obstacles) from Checkpoints (topic completion percentage: 25%, 50%, 75%, 100%).
  - Flag saving and editing uses an independent, dedicated pipeline; saving a flag displays contextual toast notifications ("Flag saved! 🚩" / "Flag removed") without modifying beat progress or clearing checkpoints.
- **Modernized Weekly Calendar Day Tiles**:
  - Sleek rectangular frosted glass day tiles with top-right floating circular effort badges and heat-mapped indicators matching theme accent colors.
- **Unified Data Vault**:
  - Merged separate backup cards into a single cohesive Data Vault in Settings, combining automated 7-day rolling local snapshots with manual native JSON export/import.
- **Flow Header & Tracker Navigation**:
  - Fixed greeting/welcome header on the Flow screen with a horizontal scrollbar for effortless tracker switching, eliminating clutter.
- **App Version Metadata**:
  - Updated app version across settings, metadata footer, and build configs to `v1.0.2`.

### Removed
- **Todo Suggestion System**: Completely stripped automatic daily topic suggestion mechanism, sequential queue walker (`walkQueueToFillBudget`), `daily_missions` database table, repository, and auto-pull study-ahead logic.
- **Revision Suggestion Engine**: Completely removed spaced repetition forgetting curve suggestion service (`RevisionService`, `RevisionItem`), `DailyRevisionBoard` UI component, and local AI revision candidate ranking.
- **Backlog Manager & Lag Recalibration**: Removed backlog debt calculation, shortfall streak detection (`detectShortfallTrend`, `isSustainedLag`), `_SustainedLagRecalibrationBanner`, and `BacklogDecisionSheet`.
- **Target Beat & Quota System**: Removed rigid weekly study rhythm calibration (22 beats/wk, 34 beats/wk, 8 beats/wk) and daily intensity quotas from Onboarding and Settings; streamlined onboarding to 3 self-paced steps.

### Fixed
- **Model Auto-Download Onboarding & Restart Loop**: Fixed race condition during initial setup where leaving the AI model selection step triggered duplicate concurrent download streams, corrupting file state and forcing a re-download on first app reopen. Added immediate mutex locking, already-downloaded fast-path checks, and deduplicated startup resume triggers.
- **Checkpoint 0% Toast on Flag Save**: Fixed bug where editing or adding a flag note triggered an erroneous "Checkpoint saved: 0%" toast and wiped beat progress.
- **Flag Note Edit Dialog Navigation**: Fixed bug where tapping "Edit Notes" on a flagged beat opened the checkpoint percentage picker instead of the flag note editor.
- **Standalone Video Chapter Effort Calculation**: Fixed calculation for single videos where effort points were previously miscalculated; now accurately computes duration deltas between consecutive chapter timestamps.
- **Tracker Effort Points Display**: Fixed main Explore screen tracker cards to show actual total effort points rather than raw beat counts.
- **UI Overflow Protection**: Prevented `RenderFlex` overflows across long chapter titles, video resources, and model download banners.

## [1.0.1] - 2026-09-19

### Added
- **WhatsApp-Style Resilient Local Daily Auto-Backup**:
  - Ambient on-device backup system that automatically captures daily snapshots to resilient local device storage (`Documents/Rythem/Backups/`).
  - Automatic rolling snapshot rotation: preserves `rythem_autobackup_latest.json` alongside 7 daily rolling snapshots (`rythem_autobackup_YYYY-MM-DD.json`), automatically pruning older backups.
  - **Disaster Recovery UX**: If the active SQLite database is wiped or app data is cleared, Rythem detects existing local backups on launch and prompts with a 1-tap "Restore Previous Data?" dialog.
  - **Dual-Mode Coexistence**: Both ambient automated backups and manual native file picker export/import coexist seamlessly in the Settings tab.
  - **Public User-Accessible Storage**: Backups save to user-visible `Documents/Rythem/Backups` on Android so users can easily find them in file managers (e.g. Files by Google, Samsung My Files).
  - **Storage Permissions**: Added `MANAGE_EXTERNAL_STORAGE` and `WRITE_EXTERNAL_STORAGE` in AndroidManifest for reliable filesystem persistence.
  - **Compact Snapshot Display**: Snapshot list renders clean titles (`Latest Snapshot`, `2026-09-19`) with overflow-proof flex layouts preventing `RenderFlex overflow`.
- **Mentor-First On-Device AI Alignment & Topic Subtraction**:
  - Enforced the core pedagogical invariant: *"We subtract topics from the mentor's resource, not resources from the mentor."*
  - Preserves the mentor's exact 0..N-1 video chapters without deleting, dropping, or reordering any videos.
  - Matching syllabus topics are satisfied and subtracted as the mentor's course progresses; enrichment videos are labeled as `isMentorExtra: true`.
  - Uncovered syllabus gaps cleanly group at the bottom as residual gaps for Resource 2 to fill.
  - Pure-Dart morphological English stemmer for inflectional suffixes (plurals, gerunds, verb forms).
  - Compound clause deconstruction with distributed head nouns (e.g. *"List, Dictionary & Set Comprehensions"* expands into 3 distinct concepts).
  - Expanded CS and programming ontology covering OOP, Control Flow, Error Handling, File I/O, Environments, REST APIs, Git, Testing, and Typing.
- **Single-Video Course Chapter Extraction**:
  - Live description timestamp parser that converts long single-video crash courses (e.g., 6-10 hour courses) into structured chapters and beats using description timestamps (`00:00`, `01:23:45`).
- **Start Date Preservation & Historical Metrics Sync**:
  - Added persistent `startDate` field to `RoadmapEntity` (SQLite Schema v2).
  - Editing target dates or track parameters preserves original start dates and historical beat completions.

### Fixed
- **Flow To-Do Architecture Overhaul & Persistent Daily Missions**:
  - Replaced fragile JSON settings cache with a dedicated SQLite `daily_missions` table with `ON DELETE CASCADE` foreign-key protection.
  - Fixed cross-chapter interleaving: beats from Chapter 1 are strictly exhausted before Chapter 2 beats are queued.
  - Fixed premature task disappearance and premature Evening Unlock: completed tasks stay visible with strikethrough all day without erasing pending tasks.
  - Optimistic instant checkbox toggles with debounced sequential SQLite write queuing to prevent race conditions during rapid tapping.
- **Flow Streak Bug & Calendar Synchronization**:
  - Fixed artificial 3-day default streak clamp (`_currentStreak = streak >= 3 ? streak : 3`); streak accurately reflects real completion logs from day 0.
  - Unified data pipeline between Flow Screen and Metrics Screen using identical 7-day activity records.
  - Horizontally scrollable calendar in Flow Screen accurately highlights active study days.
- **Settings UI & Tab Version**:
  - Updated app version footer to `v1.0.1`.
  - Displayed explicit storage path location chip (`📁 Documents > Rythem > Backups`) in the backup settings card.

---

## [1.0.0] - 2026-09-16

### Initial Production Release

#### Learning Operating System & Pacing Engine
- **"Beats Over Clocks" Core Philosophy**: Milestone-driven learning framework that eliminates toxic overdue banners and arbitrary timers.
- **Dynamic Pacing Dilution**: Mathematical engine that redistributes remaining effort across user calendar windows when days are missed.
- **Evening Unlock**: Psychological rest confirmation activated upon completing daily mission quotas.
- **Configurable Study Rhythm**: 7-day custom study intensity schedules (Default, Accelerated, Gentle).

#### Curriculum Ingestion & Alignment
- **YouTube Playlist Extraction**: Recursive batch extraction supporting extensive playlists (100+ to 230+ videos) with chunked chapter clustering.
- **Syllabus Outline Parsing**: Markdown syllabus ingestion with semantic matching and "Mentor Extra" alignment indicators.
- **Resource Linking**: Direct one-tap linking of videos, timestamps, and documentation to individual beats or entire chapters.

#### Offline-First Local Intelligence
- **Private On-Device AI Mentorship**: Direct support for Compact Mentor (Qwen 2.5 0.5B) and Balanced Mentor (Qwen 2.5 1.5B) via GGUF local inference.
- **Automatic Background Downloading**: Seamless model selection during onboarding with automatic background downloads and graceful heuristic fallbacks.
- **Pedagogical Concept Explanations**: Instant on-device explanations for confusing beats and shortfall root cause analysis.
- **On-Demand Revision System**: Spaced repetition engine with forgetting curve calculations, active recall prompts, and prerequisite linking.

#### Performance & Fluid Glass Design System
- **60/120 FPS Rendering**: State preservation across tabs with `FadeIndexedStack` and isolated repaint boundaries for frosted glass surfaces.
- **Frosted Liquid Glass Aesthetic**: Ambient glassmorphism with dynamic specular highlights, custom blur shaders, and dark/light theme support.
- **Haptic Tactility**: Selection haptics on checkboxes, accordions, and navigation controls.

#### Data Reliability & Disaster Recovery
- **Embedded SQLite Architecture**: High-performance local database with foreign key cascade protection and transactional integrity.
- **In-Flight Synchronization Protection**: Debounced real-time event pipeline ensuring Flow (Todo) and Explore (Tracker) never drop concurrent task completions.
- **Full Backup & Restore**: Comprehensive export and restoration of all user roadmaps, chapters, beats, daily activity logs, and settings.
- **Clean State**: Production-ready initialization with no hardcoded sample roadmaps or dummy seed records.
