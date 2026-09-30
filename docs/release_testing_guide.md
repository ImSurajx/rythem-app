# Rythem App — Comprehensive Release Testing & QA Guide (v1.0.2)

This guide provides a structured, exhaustive QA testing protocol covering every user journey, feature, edge case, and visual transition in **Rythem**. Follow this guide sequentially or by section to validate the build prior to the stable release.

---

## Pre-Requisites & Test Matrix

| Component | Target Spec / Minimum | Tested Device / Emulators |
| :--- | :--- | :--- |
| **Android OS** | Android 9.0 (API 28) to Android 14 (API 34) | Stock Android, HyperOS / MIUI, OneUI |
| **Storage Permissions** | Scoped Storage (API 30+) & Granular Media (API 33+) | Internal & External Documents Storage |
| **Display Refresh** | 60Hz & 90Hz/120Hz High Refresh Rate | Bouncing physics, Dock animation, Cross-fade |
| **Theme Modes** | Pure Dark (`#090A0D`), Glass Light (`#F7F8FA`) | System auto-switch, manual toggle |

---

## Test Suite 1: First Launch & Onboarding Experience

### Objective
Ensure first-time installation initializes the SQLite database cleanly, presents the brand philosophy, and transitions seamlessly into the main app.

- [ ] **1.1 Clean Install Launch**
  - **Action:** Clear app storage or perform a fresh install. Launch the application.
  - **Expected:** Instant launch with no black flashes. Drift database tables (`roadmaps`, `chapters`, `beats`, `beat_logs`, `app_settings`) are created with 0 errors.
- [ ] **1.2 Onboarding Carousel & Visuals**
  - **Action:** Swipe through the onboarding slides.
  - **Expected:** Staggered card animations render smoothly. Brand icons and copy align without horizontal overflow.
- [ ] **1.3 Initial Setup & Skip Logic**
  - **Action:** Complete onboarding either by setting an initial focus goal or tapping "Get Started / Skip".
  - **Expected:** Flag `hasCompletedOnboarding` is saved to `app_settings`. The app lands directly on the **Flow** screen.
- [ ] **1.4 Persistence on App Restart**
  - **Action:** Force kill the app and relaunch.
  - **Expected:** Onboarding does **not** appear again; app immediately opens the main dashboard.

---

## Test Suite 2: The Flow Screen (Daily Ambient Execution)

### Objective
Verify the daily focus loop, beat progression, effort indicators, reflections, and non-punitive friction flagging.

- [ ] **2.1 Header & Roadmap Switching**
  - **Action:** Tap the roadmap switcher in the frosted glass header.
  - **Expected:** Dropdown/bottom sheet displays all active roadmaps. Selecting a different roadmap updates the hero card and progress counters immediately.
- [ ] **2.2 Active Focus Hero Card & Ambient Glow**
  - **Action:** Observe the currently active beat card in both dark and light modes.
  - **Expected:** Liquid glass frosted container with emerald ambient glow shimmer. Progress bar matches completed percentage.
- [ ] **2.3 Effort Badge Presentation**
  - **Action:** Check the effort tag on the active beat (e.g. `LIGHT`, `MODERATE`, `HEAVY`, `INTENSE`).
  - **Expected:** Text is legible, properly padded inside the pill container, and does not clip adjacent chapter text.
- [ ] **2.4 Resource Launcher**
  - **Action:** Tap the resource link/button on an active beat (e.g. YouTube video, URL, or article).
  - **Expected:** Launches the URL in an external browser or modal without app crashes.
- [ ] **2.5 Checkpoint Logging (`CheckpointDialog`)**
  - **Action:** Tap the Checkpoint / Progress action.
  - **Expected:**
    - Dialog smoothly scales up (`0.92 → 1.0`) and fades in.
    - Set progress to a partial percentage (e.g., `45%`) and enter notes (e.g., *"Completed through section 2 practice problems"*).
    - Tap **Save Checkpoint**.
    - Dialog smoothly scales down and fades out.
    - Active beat updates its partial progress instantly.
- [ ] **2.6 Confusion / Friction Flagging (`ConfusingBeatDialog`)**
  - **Action:** Tap the Flag / Confusion icon on the active beat.
  - **Expected:**
    - Smooth dialog appears with non-punitive messaging ("Flag Friction - No Guilt").
    - Enter obstacle notes (e.g., *"Need extra review on recursion base cases"*).
    - If local AI is active, verify suggestion prompt or fallback note saving.
    - Tap **Save Note & Flag**.
    - Beat reflects flagged state with orange/amber accent.
- [ ] **2.7 Beat Completion & Streak Increment**
  - **Action:** Tap **Complete Beat** or toggle the completion checkbox.
  - **Expected:**
    - Beat strikes through and shifts status to completed.
    - The next chronological beat in the chapter automatically becomes the active focus.
    - Streak count increments or updates without penalty.
- [ ] **2.8 Upcoming Beats ("Next Up") List**
  - **Action:** Scroll the vertical list of upcoming beats.
  - **Expected:** Inertia-rich iOS-style bouncing scroll physics. No rigid clamping wall when reaching top or bottom.

---

## Test Suite 3: Explore Screen & Flag Notes Notebook

### Objective
Test multi-track curriculum management, track creation methods, and the unified Flag Notes notebook.

### Part A: Trackers Section
- [ ] **3.1 Tracker Cards & Overview**
  - **Action:** Navigate to **Explore** tab, select **Trackers**.
  - **Expected:** All enrolled roadmaps display with title, category pill, chapter counts, and percentage progress bars.
- [ ] **3.2 Roadmap Detail Screen Transition**
  - **Action:** Tap on any roadmap card.
  - **Expected:** Smooth slide transition into `RoadmapDetailScreen` with zero frame drops.
- [ ] **3.3 Manual Track Creation (`+ New Track`)**
  - **Action:** Tap **+ New Track**, enter Title, select a Category (or tap **+** to add a custom category using the smooth category dialog), choose a target date, and tap **Create**.
  - **Expected:** Custom category popup scales in/out smoothly. New tracker is persisted to SQLite and appears immediately in Explore.
- [ ] **3.4 Playlist / Syllabus Ingestion**
  - **Action:** In New Track modal, paste a YouTube playlist URL or upload a markdown/text syllabus file.
  - **Expected:**
    - Playlist parser extracts titles, video durations, and clusters them into chapters.
    - Ingestion handles long playlists (>100 or 200 items) without memory pressure or UI freezing.
- [ ] **3.5 Tracker Deletion Confirmation**
  - **Action:** Tap the delete icon on a roadmap.
  - **Expected:** Smooth confirmation dialog appears. Canceling dismisses smoothly without deleting; confirming deletes the roadmap, chapters, and beats from SQLite.

### Part B: Flag Notes Notebook Section
- [ ] **3.6 Flag Notes Discovery**
  - **Action:** In Explore, tap the **Flag Notes** tab toggle.
  - **Expected:** Smooth switch. Displays all beats previously flagged in Flow or Roadmap Details.
- [ ] **3.7 Real-Time Note Synchronization**
  - **Action:** Verify notes saved during Test 2.5 and 2.6 appear here with:
    - Tracker / Course Title
    - Chapter name and Beat title
    - Exact note text and percentage badge
- [ ] **3.8 Course / Roadmap Filter Chips**
  - **Action:** Tap different course filter pills (e.g. "All", "DSA", "Precalculus").
  - **Expected:** List filters immediately to notes belonging to the selected course.
- [ ] **3.9 Search Filter**
  - **Action:** Type keywords in the search bar.
  - **Expected:** Real-time query matching across note content and beat titles.
- [ ] **3.10 Edit & Resolve Flag**
  - **Action:** Tap **Edit Checkpoint** on a note card to modify the reflection, or tap **Resolve Flag**.
  - **Expected:** Dialog opens smoothly; updates reflect instantly across both Explore and Flow screens.

---

## Test Suite 4: Roadmap Detail View (`RoadmapDetailScreen`)

### Objective
Validate deep-dive curriculum exploration, chapter accordions, and beat state overrides.

- [ ] **4.1 Header & Progress Bar**
  - **Action:** Open a roadmap detail screen.
  - **Expected:** Displays roadmap category, target completion date, dynamic beat ratio (e.g. `14 of 48 Beats`), and smooth progress bar.
- [ ] **4.2 Chapter Accordions (Expand / Collapse)**
  - **Action:** Tap various chapter headers to expand and collapse them.
  - **Expected:** Smooth accordion expansion. Nested beats display duration, state icon, and checkpoint indicator.
- [ ] **4.3 Direct Beat Completion & State Toggle**
  - **Action:** Tap the status icon on a beat inside an accordion.
  - **Expected:** Toggles between Pending and Completed. Progress bar and beat count update reactively.
- [ ] **4.4 Rapid Toggle Stress Test**
  - **Action:** Rapidly tap multiple beat checkboxes within 1–2 seconds.
  - **Expected:** Database event bus syncs cleanly; no race conditions or inconsistent counts.

---

## Test Suite 5: Metrics & Analytics Screen

### Objective
Ensure analytics data computes accurately from historical beat logs without layout distortion.

- [ ] **5.1 Overview Stats Cards**
  - **Action:** Open the **Metrics** tab.
  - **Expected:** Displays Total Focus Hours, Completed Beats, and Active Trackers accurately matching SQLite database records.
- [ ] **5.2 Weekly Velocity Chart**
  - **Action:** Inspect the 7-day velocity bar chart.
  - **Expected:** Daily bars represent completed beats or focus time. Highlight on the current day.
- [ ] **5.3 Category Distribution**
  - **Action:** Inspect category breakdown pills and distribution meters.
  - **Expected:** Percentage distributions sum to 100%. No text overlapping on small screens.
- [ ] **5.4 Streak Counter & Freeze Protection**
  - **Action:** Verify streak count and status.
  - **Expected:** Reflects consecutive active days; shows freeze/recovery status non-punitively.

---

## Test Suite 6: Settings, Local AI Engine & Universal Backup

### Objective
Verify theme persistence, local inference download lifecycle, and backup export/restore across storage locations.

### Part A: Appearance & Theme
- [ ] **6.1 Theme Switching**
  - **Action:** In Settings, toggle between **Dark**, **Light**, and **System**.
  - **Expected:** Theme switches instantaneously with specular border and glass gradient re-rendering. No color inversion glitches. Setting persists after restart.

### Part B: Local AI Engine (Optional / Offline Ingestion)
- [ ] **6.2 Model Tiers Display**
  - **Action:** View the Local AI Engine section in Settings.
  - **Expected:** Displays Nano (~1.5GB) and Balanced (~3.8GB) tiers with descriptions.
- [ ] **6.3 Model Download Lifecycle (if testing model)**
  - **Action:** Initiate model download, pause, resume, or cancel.
  - **Expected:** Progress bar updates smoothly; cancellation cleans up partial files; completed download enables on-device breakdown.

### Part C: Universal Storage & Backup System
- [ ] **6.4 Manual "Backup Now" Execution**
  - **Action:** Tap **Backup Now** in Settings.
  - **Expected:**
    - If permission requested, system storage prompt appears.
    - Creates a backup in the universal location:
      - Primary: `/storage/emulated/0/Download/RythemBackups/`
      - Fallback: App External Storage (`/Android/data/.../files/backups`)
    - Shows a success toast with the exact destination path.
- [ ] **6.5 Automatic Snapshot Creation**
  - **Action:** Complete or add a beat, then return to Settings.
  - **Expected:** Automated snapshot manager has generated a timestamped snapshot without blocking UI threads.
- [ ] **6.6 Restore Snapshot Modal**
  - **Action:** Tap **Restore from Snapshot**.
  - **Expected:**
    - Bottom sheet lists available snapshots with timestamps and beat counts.
    - Selecting a snapshot triggers smooth confirmation dialog.
    - Confirming restores state cleanly and reloads all screens.
- [ ] **6.7 Export & Import Backup File**
  - **Action:** Tap **Export Backup** to save a `.json` backup. Then tap **Import Backup** and select that file.
  - **Expected:** File picker opens, file is validated, smooth confirmation dialog appears, and data restores with 100% fidelity.

---

## Test Suite 7: Smooth Transitions, Motion & Scrolling Overhaul

### Objective
Validate the new UI motion improvements requested in v1.0.2.

- [ ] **7.1 Nav Bar Switching Transition**
  - **Action:** Tap consecutively between `Flow`, `Explore`, `Metrics`, and `Settings` in the bottom glass dock.
  - **Expected:**
    - The active screen smoothly cross-fades and gently scales (`0.985 → 1.0` at 320ms with `Curves.easeOutCubic`).
    - The departing screen smoothly fades out.
    - No sudden jump, flicker, or blank white frame.
- [ ] **7.2 Scroll Position Preservation Across Tabs**
  - **Action:** Scroll deep into the Explore Flag Notes list or Settings. Switch to Flow, then switch back to Explore.
  - **Expected:** The scroll offset remains exactly where you left it.
- [ ] **7.3 Global Bouncing Scroll Physics**
  - **Action:** Fling scroll on Flow, Explore, Metrics, Settings, and inside dialogs.
  - **Expected:**
    - Fluid deceleration with inertia.
    - Top and bottom edges bounce with smooth rubber-band resistance (iOS style), replacing default rigid clamping.
- [ ] **7.4 Dialog Popups: Smooth Entrance & Disappearance**
  - **Action:** Open and close `ConfusingBeatDialog`, `CheckpointDialog`, and delete confirmation dialogs.
  - **Expected:**
    - **Entrance:** Dialog smoothly scales from `0.92 → 1.0` while fading in (300ms).
    - **Exit / Dismissal:** Dialog smoothly shrinks from `1.0 → 0.92` while fading out (`Curves.easeInCubic`). No abrupt disappears.
- [ ] **7.5 Glass Bottom Dock Button Scale & Highlight**
  - **Action:** Tap dock icons slowly and observe button feedback.
  - **Expected:** Gentle 320ms bounce scale (`1.08x`), glowing background highlight transition, and haptic feedback.

---

## Test Suite 8: System Stress, Edge Cases & App Lifecycle

- [ ] **8.1 Long Text Overflow Test**
  - **Action:** Create tracks and beats with very long names (80+ characters) or URLs.
  - **Expected:** Gracefully wraps or truncates with ellipsis. Zero `RenderFlex` yellow/black striped overflow errors.
- [ ] **8.2 Backgrounding & Memory Kill**
  - **Action:** Send app to background while editing notes or halfway through a track. Reopen from recent apps.
  - **Expected:** State restores instantly without crash.
- [ ] **8.3 Low Storage / Offline Mode**
  - **Action:** Turn on Airplane Mode (disconnect WiFi and Mobile Data).
  - **Expected:** 100% of core app features (Flow, Checkpoints, SQLite persistence, Backups, Flag Notes, Metrics) function completely offline.

---

## Release Checklist Sign-Off

Before publishing the APK/AAB build for production release:

1. [ ] `flutter analyze` returns **0 issues found**.
2. [ ] `flutter test` executes all test suites with **100% passing (142/142 tests)**.
3. [ ] Signed git commit on `master` with release tag attached.
4. [ ] App icon renders crisp and centered across Android adaptive icon launchers (Stock, HyperOS, OneUI).
5. [ ] Release APK/AAB built with `flutter build appbundle --release` / `flutter build apk --release`.
