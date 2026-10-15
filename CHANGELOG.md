# Release

## Rythem v1.1.3

Release removing inline tag clutter from task cards, grouping tasks by category with headers on the top-left, ensuring visible custom task titles, and bumping version to 1.1.3.

---

### ✨ Highlights & Improvements

- **Top-Left Category Grouping**:
  - Tasks in both Open Lab and user-driven tracks are organized under category group cards with the category indicator badge (`⚡ REVISION`, `⚡ PRACTICE`, `⚡ OPEN LAB`, etc.) prominently positioned on the **top-left**.
  - Right side of group header displays aggregate effort points and completion progress (`⚡ 4.0 pts • 2/3 complete`).
- **Clean Task Cards (Zero Tag Clutter)**:
  - Removed all inline tags (`MENTOR EXTRA`, `RESOURCE $n`, and category chips) from inside individual task cards (`BeatTile`).
  - Task titles are rendered cleanly and completely unobstructed.
- **Custom Task Title Visibility & Gap Prevention**:
  - Excluded custom tasks from syllabus gap detection so tasks without a source URL remain standard task items rather than falling into "⚠️ Uncovered Syllabus Gaps".
  - Created custom tasks now have `isMentorExtra: false`.

---

## Rythem v1.1.2-preview

Preview release fixing native APK package installation via Android FileProvider, removing front category chips for cleaner cards, shortening button wording, and unifying curriculum task tiles.

---

### ✨ Highlights & Fixes

- **Native Android APK Installer Bridge**:
  - Replaced raw URL file launch with native Android `FileProvider` (`content://`) intent and `REQUEST_INSTALL_PACKAGES` permission handling.
  - Automatically triggers the system "Install Unknown Apps" permission prompt if required and launches the native package installer without redirecting to GitHub in the browser.

- **Clean Task Tile Typography & Design**:
  - Removed prepended orange category chips from the front of custom task cards in both Open Lab and curriculum tracks.
  - Titles now align cleanly and consistently with standard curriculum topics.
  - Duration and effort points remain subtly indicated in the metadata line (`⚡ 6.0 • 1h`).

- **Unified Curriculum Task Tiles**:
  - Custom tasks added to structured courses now flow inline within their parent chapter as standard task completion tiles rather than splitting into separate amber milestone category blocks.
  - Open Lab Activity Log displays as a clean flat list filtered by top category chips.

- **Streamlined UI Wording**:
  - Flow Screen Open Lab action simplified to **`⚡ Log Task`**.
  - Custom task creation dialog buttons shortened to **`Log Task`** (Open Lab) and **`Add Task`** (curriculum tracks).

---

## Rythem v1.1.1-preview

Preview release introducing the default **Open Lab** tracker for independent projects & non-syllabus learning, duration-based effort calculation (10 min = 1 effort point), and dynamically extensible task categories.

---

### ✨ Highlights & Core Capabilities

- **Default "Open Lab" Tracker**:
  - Auto-seeded ambient tracker (`[ 🧪 OPEN LAB ]`) pre-loaded on first launch for unconstrained learning (open-source contributions, test prep, independent projects).
  - Keeps daily study streaks active without polluting formal structured curricula.
  - Streamlined Flow interface with a prominent **`[ ⚡ Log Task / Project ]`** action (omits redundant topic-pulling).

- **Duration-to-Effort Conversion (10 min = 1 point)**:
  - Direct duration selection via preset chips (`15m`, `30m`, `45m`, `1h`, `1.5h`, `2h`, `3h`) and custom hours entry.
  - Dynamic real-time calculation badge (e.g. `1.5 hrs • ⚡ 9.0 pts`).
  - Standardized across custom task creation in both Open Lab and curriculum tracks.

- **Dynamic, User-Defined Task Categories**:
  - Universal default starter categories (**Revision**, **Practice**, **Reading**, **Project**, **General**) designed for any field of study.
  - Inline **`+ Add Category`** creation tool allowing learners to define, persist, and reuse personalized categories.
  - Persisted locally with SQLite and instant in-memory cache.

- **Activity Log with Category Filters & Duration Badges**:
  - Interactive category filter chips (`All (N)`, `${cat} (N)`) at the top of the Open Lab Activity Log.
  - Topic cards display readable duration alongside points (`⚡ 6.0 • 1h`).

---

## Rythem v1.1.0-Stable

Stable release featuring categorized custom study tasks, on-device GitHub update checks with streaming installer, padded adaptive launcher icons, and zero-cloud streak protection.

---

### ✨ Highlights & Core Capabilities

- **Categorized Custom Study Tasks**:
  - Learners can now create custom study sessions directly within any tracker for non-linear learning (revision, problem solving, side projects).
  - Tasks can be assigned custom categories: **Revision**, **Practice & Problems**, **Deep Dive**, **Side Project**, and **General**, replacing raw placeholder labels with clean milestone headers and amber `⚡ [CATEGORY]` badges.
  - One-task focus constraint per tracker to maintain ambient clarity and prevent backlog accumulation, with single-tap discard support.

- **Chronological Curriculum Appending & Dynamic Re-Indexing**:
  - Completed custom tasks append directly after the user's last completed topic in the tracker, maintaining true chronological learning history.
  - Subsequent topics automatically shift their sort orders without data loss.

- **Dual-Action Flow Tracker Cards**:
  - Flow screen tracker cards now provide dual frosted glass actions: **`[ 🎯 Pull Next Topic ]`** (sequential curriculum) and **`[ ⚡ Custom Task ]`** (modal creation).
  - Allows logging custom study tasks even if a tracker is 100% completed.

- **Zero-Cloud Streak Protection**:
  - Completing custom tasks automatically writes activity records into `beat_logs`, maintaining daily study streaks and crediting toward daily pacing budgets.

- **Direct In-App Software Updates**:
  - Integrated "Software Update" card in Settings connected directly to the official GitHub Releases API.
  - Streaming APK downloads with chunk-by-chunk progress tracking, received/total MB indicators, and cancellation support matching the on-device AI model downloader.
  - One-tap APK installation trigger with fallback to release web browser notes.

- **Refined Adaptive App Icon & Corner Padding**:
  - Added padding and clearance to `assets/icons/logo.png` ensuring full visibility within circular, squircle, and teardrop Android adaptive launcher masks.

---

### 📝 Key Commits & Improvements

- `feat(flow)`: custom study task creation, effort points, and curriculum appending
- `feat(categories)`: structured task categories, interactive chip selection, and curriculum badges
- `feat(updater)`: in-app GitHub update checker, streaming APK download, and installer trigger
- `fix(icon)`: adaptive launcher icon corner clearance and multi-density mipmap regeneration
- `test`: comprehensive unit and widget test suite covering custom tasks, updates, and flow interactions

---

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
  - Decoupled Flag Notes (doubts, confusion points, conceptual obstacles) from Checkpoints (topic completion percentage: 25%, 50%, 75%, 100%).
  - Dedicated "Flag Notes" notebook tab in Explore with search, tag filters, and inline note previews.
  - One-tap navigation from a flagged note directly into its roadmap and chapter context.
  - Flag saving and editing uses an independent, dedicated pipeline without clearing checkpoints.

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
