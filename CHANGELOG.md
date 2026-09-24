# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2-pre] - 2026-09-24

### Added
- **Feature 1: Core Decoupling & Pure User-Driven "Today's Focus"**:
  - Decoupled Daily Missions from rigid calendar days and automated over-allocation.
  - "Today's Focus" is purely user-driven: users select what they want to tackle today with dedicated Add/Remove sheet and custom reordering.
  - Immediate optimistic status sync across tabs via `DatabaseEventBus`.
- **Feature 2: "Complete in Parts" & Multi-Part Task Splitting**:
  - Long beats or videos (e.g. 2–3 hour deep dives) can be split into smaller, manageable chunks (Part 1, Part 2, etc.) directly from Flow and Tracker.
  - Sub-parts inherit the parent beat's chapter and roadmap context, maintaining consistent progress metrics.
  - Clean split modal sheet with part name and duration configuration.
- **Feature 3: Full Tracker Customization (Add Chapters & Topics)**:
  - Users can customize and extend any roadmap curriculum with custom chapters and topics.
  - Intuitive "Add Chapter" and "Add Topic" modal bottom sheets with validation, auto-sequencing, and duration inputs.
  - Custom items persist in SQLite and are instantly reflected across Explorer accordions and Flow selectors.
- **Feature 4: Intelligent Pace Coach & Non-Intrusive Warnings**:
  - Non-intrusive Pace Coach card in the Flow screen providing subtle, supportive pacing guidance without toxic overdue banners.
  - Mathematical pace analysis comparing target completion dates with remaining hours and current velocity.
  - Dedicated interactive "Timeline Adjuster" modal bottom sheet allowing users to smoothly recalibrate target dates or daily effort quotas in one tap.
- **Feature 5: Clean Revision Shelf (Spaced Retention)**:
  - Spaced retention shelf with non-punitive, optional review queues.
  - "Mark for Revision" action sheet with 1-tap presets (1 Day, 3 Days, 7 Days, or Custom).
  - Ambient review badge counts and fluid dismissal animations.
- **Feature 6: YouTube Timestamps & Community Comments Chapter Extraction**:
  - Enriched YouTube ingestion supporting both native video chapters, description timestamps, and community pinned comment timestamps.
  - Intelligent multi-layer regex parser that extracts valid timestamps (`MM:SS` or `HH:MM:SS`) and labels from video comments.
  - Automatically deduplicates and merges extracted topics into cleanly structured roadmaps.
- **Feature 7: In-App GitHub Releases Updater & Modal Sheet**:
  - Ambient GitHub Releases update checker directly integrated into Settings tab (`SoftwareUpdateCard`).
  - Strict Semantic Versioning (`SemVer`) comparator supporting build numbers and pre-release tags (`1.0.2-pre+3`).
  - Liquid glass Update Modal Sheet with Markdown release notes, formatted date/size chips, and animated download progress.
  - Streamed background APK downloads with live percentage, downloaded megabytes, and transfer speed (MB/s).
  - Native Android `PackageInstaller` / FileProvider integration via MethodChannel `com.rythem.rythem_app/updater` for direct in-app APK installation.

---

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
