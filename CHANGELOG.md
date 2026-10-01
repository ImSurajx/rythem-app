# Release

## Rythem v1.0.0-stable

Welcome to **Rythem v1.0.0-stable** — an ambient, milestone-driven learning operating system and curriculum orchestrator built with a local-first, zero-cloud architecture.

---

### ✨ Highlights & Core Capabilities

- **Effort Points System (1 Effort Point = 10 Minutes)**:
  - Replaced raw beat counts with meaningful, time-scaled Effort Points throughout the entire application.
  - Standalone video chapter effort calculation: dynamically computes exact chapter effort points using timestamp deltas `(nextChapterTimestamp - currentChapterTimestamp) / 10 min` (or `(videoDuration - currentChapterTimestamp) / 10 min` for the final chapter).
  - Multi-playlist video duration remapping with fast batch processing and duration normalization.
  - Proportional effort point allocation for partial checkpoints (25%, 50%, 75%, 100%).
  - 7-day metric performance graphs and calendar tiles display actual daily effort points instead of arbitrary beat counts.

- **Flag Notes & Doubt Tracking Notebook**:
  - Completely decoupled Flag Notes (doubts, confusion points, conceptual obstacles) from Checkpoints (topic completion percentage: 25%, 50%, 75%, 100%).
  - Dedicated "Flag Notes" notebook tab in Explore with search, tag filters, and inline note previews.
  - One-tap navigation from a flagged note directly into its roadmap and chapter context.
  - Flag saving and editing uses an independent, dedicated pipeline; saving a flag displays contextual toast notifications ("Flag saved! 🚩" / "Flag removed") without modifying beat progress or clearing checkpoints.

- **Fluid Motion Design System & Liquid Aesthetics**:
  - Smooth page navigation transitions with cross-fading via `SharedAxisTransition` / `PageTransitionSwitcher`.
  - Global iOS/macOS-style `BouncingScrollPhysics` across all screens for silky, responsive scrolling.
  - Interactive frosted glass dialogs with smooth entry and exit scaling/fading (`SmoothDialog`).
  - Integrated `flutter_animate` with test-safe central configuration (`RythemMotion`), floating dock rebounds, and staggered card entrances.
  - Monochrome liquid frosted glass design system with light and dark themes.

- **Resilient Data Vault & Local Backup**:
  - Unified Data Vault in Settings combining automated 7-day rolling local snapshots with manual native JSON export/import.
  - Native Android storage permission bridge with fallback to application documents storage.
  - Automated database linking, schema migrations, and backward-compatible snapshot discovery.

- **On-Device AI Models (100% Private & Local)**:
  - Powered by local Small Language Models (Qwen 2.5 0.5B and 1.5B GGUF) for intelligent curriculum clustering and mentor Q&A without cloud dependencies.
  - Resilient background model download manager with HTTP Range resumption and mutex protection.
  - Stabilized initial onboarding and restart loop with immediate file verification.

- **Multi-Playlist & Resource Synchronization**:
  - Background resource synchronization engine that auto-refreshes video durations, metadata, and timestamps without freezing or timing out.
  - Multi-renderer YouTube playlist and video extraction supporting unbounded playlists and mobile share sheet URLs.
  - Preserves source playlist URLs with `list` query parameters on fresh tracker creation.

- **User-Driven Focus & Pacing**:
  - Pure-math dynamic pacing redistribution without guilt or rigid hour countdowns.
  - Replaced rigid automated queue generation with self-paced topic pulling ("Focus Next" or pull directly into Today's Focus).
  - Completed topics remain permanently visible in Today's Focus with strike-through styling and instant 1-tap Undo protection.
  - Modern rectangular frosted glass day tiles with top-right floating circular effort badges and heat-mapped indicators matching theme accent colors.

---

### 📝 Commit History

- `abf70f6` fix(ai): eliminate onboarding double-download race and stabilize restart loop
- `27498f4` fix(flags): decouple flag notes from checkpoints and fix status toast
- `088ae99` fix(sync): optimize single-video chapter sync to group by videoId and remap effort points
- `c85e1c6` fix(ingestion): calculate exact chapter effort points for single video resources
- `27f67ad` fix(ui): greeting header, flag note edit dialog, tracker effort points, and 7-day metric effort units
- `f207b96` docs: add comprehensive end-to-end QA release testing guide
- `39bef89` feat(ui): smooth navigation cross-fade, global bouncing scroll physics, and dialog animations
- `ea92d78` fix(flow): connect ConfusingBeatDialog to persistent notes storage and prefill initial note
- `de4c273` feat(motion): integrate flutter_animate with central test-safe config, dock rebound, and staggered entrances
- `fc4b298` feat(explore): introduce Flag Notes notebook section with search, filters, and checkpoint management
- `b75c4d2` fix(backup): add native Android storage permission bridge, universal resilient backup fallback, and padding to effort badge
- `177bdac` feat: float effort badge on top-right of square day tile & add manual backup creation
- `b43bd3c` feat(flow): redesign weekly calendar day tile with top-right effort circle and synced heat colors
- `54da8cb` fix(icon): perfectly center icon ring with equal padding and remove double inset
- `b72e1b9` fix(explore): remove big attach button and fix delete tracker dialog text color
- `8c270d8` fix(ui, backup, icon): expand weekly calendar cells, link database, save backups to Documents, add Android adaptive icon
- `45fc50e` style(flow): match mark flag icon color and icon with checkbox
- `6283df8` fix(ui): modern rectangle boxes for weekly calendar and liquid glass styling for attach dialog
- `5456311` fix(metrics): replace beat counts with actual effort point values across calendars and performance graphs
- `4ed9b73` feat: complete UI transition to effort presentation and multi-playlist automatic sync
- `72c274c` feat(ingestion): persist playlist url and list param on fresh tracker creation
- `f1b9f7a` fix(sync): ensure accurate duration extraction, remap standalone beats, and prompt for sync url
- `759fd58` fix(lint): clean up unused imports and add const constructors in tests
- `55dcb10` fix(sync-vault): fix sync timeout with fast playlist remapping, redesign backup into unified Data Vault, and stabilize snapshot storage
- `3643b4b` fix(sync-backup): resolve sync freeze, add effort UI badge, auto-normalize backup effort, and fix snapshot discovery
- `564ea8b` feat(effort): implement 10-min effort calculation, resource sync engine, and icon-only buttons
- `d8d86c3` feat(flow): add percentage checkpoints with proportional effort points and action menu
- `f11b8d4` fix: prevent download banner overflow and apply bold tracker-matched current focus header
- `60d42ba` feat: icon-only current focus with return button, and resilient background model downloading
- `86bd7c5` feat: append active topic at bottom, move return to tracker below, and balance margins
- `c091d0e` feat: show full description on focus card click and enhance tracker title with icon
- `538c8c5` feat: implement Today's Focus pull-ahead with multi-state progress cycle, undo toast, and bold styling
- `2ea8680` feat: strip todo suggestion system, backlog debt, and revision services
- `8f188fa` feat: strip target beat and study quota system from onboarding and settings
- `9a356ea` fix: support background and app closure download resumption for offline AI models
- `22cb200` fix: resolve model download failure from asset not found by re-uploading weights to release
- `3bba2a2` fix(ci): automate on-device AI model mirroring to release tag
- `aa3c34f` feat(ai): bundle offline on-device AI models in release assets and add download manager
- `3589b25` fix(pacing): recalculate daily pacing dynamically using real target dates
- `b0e1e69` feat(explore): show exact item counts on tracker cards and add search filter
- `5ec49b3` feat(explore): add dynamic topic search with auto-highlight and accordion expansion
- `09c13d7` feat(explore): add collapsible chapters, search filtering, and clean roadmap cards
- `e94e5e7` feat(flow): add manual syllabus alignment confirmation prompt for ambiguous topic matches
- `010d8a5` feat(explore): tap to play beats in YouTube and open attached learning materials
- `e5d0d8f` feat(flow): show active tracker name with color dot and streamline explore cards
- `6a4760b` fix: mobile YouTube extraction resilience and URL sanitization
- `2d53473` fix: playlist extraction multi-renderer support and zero-drop chapter division
- `3369b65` feat: add storage syllabus import, custom categories, system theme default, and unbounded playlist extraction
- `cc6740f` fix(ci): update release step to overwrite existing APK asset via gh release upload --clobber
- `160fa87` fix(ci): update release step to use GitHub CLI and configure Node compatibility
- `830632b` feat: enhance tracker UI, syllabus import, mentor sequence priority, and unbounded topics
- `d6cc176` feat(explore): implement explore screen, new track modal, and roadmap detail accordions
- `b4bd85d` feat(ui): round navigation dock and render full todo checklist across tracks
- `d2503e0` feat(flow): implement flow screen, session detail focus mode, and persistent bottom dock
- `05ef3ff` feat(ui): display daily pacing budget pill in hero card and add active status badge
- `880f666` feat(ui): add interactive on-device pacing simulation and today's queue showcase
- `2ba0d36` feat(pacing): implement pure-math pacing engine, queue walker, and backlog dilution
- `02e9a04` fix(ingestion): support modern YouTube playlist extraction and enhance tracker UI
- `02c1940` feat(ui): add interactive 3-condition ingestion test harness and custom YouTube importer
- `e4316de` feat(ingestion): implement curriculum ingestion engine, chapter clustering, and syllabus matcher
- `d8353f9` feat(ui): wire interactive showcase to live SQLite database and bundle offline fonts
- `a148d62` feat(database): implement on-device SQLite engine, data contracts, and reactive repositories
- `3510499` feat(assets): integrate official liquid glass pulse logo and Android launcher icons
- `b2035aa` feat(theme): add Apple Control Center style light frosted glass theme and theme toggle
- `9bdc440` feat(typography): adopt Poppins font family across liquid glass theme
- `9dbdd6b` feat(ui): implement monochrome liquid glass design system and interactive showcase
- `7c2dfab` feat: initialize Flutter project structure, native Android configuration, and CI pipeline
- `461faba` docs: add system architecture, design specifications, and user flows
- `ad60469` chore: configure agent rules
- `860ebdf` chore: initial commit with README and PolyForm Noncommercial License
