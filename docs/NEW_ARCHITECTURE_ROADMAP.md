# Rythem App: New Architecture & Feature-by-Feature Roadmap

This document outlines the complete plan for building Rythem's next-generation architecture. Each feature is designed to be built, tested, and verified **one by one in isolation**, ensuring maximum stability and user control.

---

## 🎯 Core Philosophy
- **User in Full Control**: The app never auto-assigns, forces, or schedules tasks without your explicit action.
- **Pace Coach, Not a Dictator**: Replaces rigid algorithmic quotas and toxic "backlog debt" with clear velocity guidelines, projected completion dates, and gentle warnings.
- **Granular Flexibility**: Long videos and multi-week projects can be split into custom parts and completed over multiple days.
- **Pedagogical Invariant**: The mentor's original sequence is sacred. Any user-added chapters or topics are appended chronologically at the bottom (FIFO).
- **100% Reliable Backups**: Data backups are pure state snapshots with zero phantom tasks or external network re-fetching on restore.

---

## 📋 Feature Breakdown (To Be Built One by One)

### Feature 1: Core Decoupling & Pure User-Driven "Today's Focus"
*Eliminates phantom tasks, auto-generation on launch, and rigid evening unlock gating.*

- **What gets removed**:
  - Remove the automatic queue walker that auto-assigned 3 beats on app launch, midnight rollover, or backup restore.
  - Remove "Evening Unlock" gating (no more arbitrary blocks on studying ahead or evening states).
  - Remove automatic task spawning when checking off items.
- **What gets built**:
  - **Clean "Today's Focus"**: Flow screen displays *only* the tasks the user has deliberately added.
  - **User Selection**: A clean **"+ Add to Today"** button on any beat inside the Roadmap Chapter view.
  - **Quick Shortcut**: An optional 1-tap **"Add Next Up"** button on Flow screen to pull the next sequential pending lesson into Today's Focus without browsing (never auto-added).
  - **"All Done for Today"**: When you finish your selected tasks, the screen shows a peaceful completion state with zero new tasks popping up.
- **Acceptance Criteria**:
  - App launch on any day opens with 0 tasks unless you added them.
  - Completing your selected tasks marks the day complete with zero surprise tasks.
  - Restoring a backup loads your exact tracks with zero auto-spawned tasks.

---

### Feature 2: "Complete in Parts" & Multi-Part Task Splitting
*Allows users to conquer 2-hour+ videos and multi-week projects across multiple days.*

- **Data Model**:
  - Add `totalParts` (integer, default 1) and `completedParts` (integer, default 0) to `BeatEntity`.
- **User Experience**:
  - Any beat has an action: **"Split into Parts"**.
  - Quick presets: *2 Parts (50% each)*, *3 Parts*, *4 Parts*, or *Custom Parts* (e.g. *Part 1: Core Theory*, *Part 2: Code Implementation*).
  - Interactive multi-part progress indicator: `Part 1 / 2 Completed`.
  - Checking off Part 1:
    - Increments `completedParts` to 1.
    - Logs today's study activity in `beat_logs` and advances your daily streak!
    - Keeps Part 2 ready for tomorrow.
    - Only marks the beat fully complete when `completedParts == totalParts`.
- **Acceptance Criteria**:
  - A 2-hour video can be split into 2 parts.
  - Checking off Part 1 registers today's streak and shows 50% progress.
  - Part 2 remains pending for the next day.

---

### Feature 3: Full Tracker Customization (Add Chapters & Topics)
*Enables students to supplement courses with custom exercises, projects, or create subjects from scratch.*

- **Mentor-First FIFO Invariant**:
  - Mentor topics keep their original order: `0, 1, 2, ... N-1`.
  - Any custom topic added by the user inside a chapter is placed at the **bottom** of that chapter.
  - Multiple user additions follow chronological FIFO sequence (`Mentor -> User 1 -> User 2 -> User 3`).
  - Custom chapters added to a roadmap are placed at the **very bottom** of the tracker.
- **User Actions**:
  - **"+ Add Topic"**: Inside any chapter accordion, adds a custom task with title, estimated minutes, optional parts, and optional notes/link.
  - **"+ Add Chapter"**: At the bottom of a roadmap, adds a custom module.
  - **"Create Custom Subject"**: Create a tracker from scratch without needing a YouTube playlist (e.g. *"College Calculus"*, *"System Design Interview Prep"*).
  - **Edit / Delete**: Ability to edit titles or delete user-added items.
- **Acceptance Criteria**:
  - Adding a topic inside Chapter 1 places it after all mentor videos.
  - Adding a custom chapter places it after all mentor chapters.
  - Creating a custom tracker works with zero YouTube dependency.

---

### Feature 4: Intelligent Pace Coach & Non-Intrusive Warnings (No Backlog Debt)
*Replaces toxic backlog debt and the rigid 7-day hourly matrix with a clear, helpful navigation coach.*

- **What gets removed**:
  - Remove the rigid 7-day hourly schedule matrix (`Light / Normal / Intense / Rest`).
  - Remove artificial "backlog debt" calculations and forced recalibration dialogs.
- **What gets built**:
  - **Pace Health Calculation**:
    - Evaluates your real velocity (average completed topics/parts per active day).
    - Computes `Projected Completion Date = Today + (Remaining Topics / Velocity)`.
  - **Clear Status Badge**:
    - 🟢 **On Track**: Projected finish $\le$ Target Date.
    - 🟡 **Behind Schedule**: Projected finish $>$ Target Date (e.g. *"5 days behind target"*).
    - ⚪ **Open Pace**: Untimed roadmap with no target deadline.
  - **Guideline Readout**:
    - *"To finish by your target date (Nov 30), aim for ~1.5 lessons per day."* (Informative only, never enforced).
  - **Gentle Warning Card**:
    - If behind schedule, offers 1-tap options: *"Extend target date by 7 days"* or *"Keep current target"*.
- **Acceptance Criteria**:
  - Accurately projects completion date based on real user velocity.
  - Shows gentle warnings without ever modifying curriculum or adding forced tasks.

---

### Feature 5: Clean Revision Shelf (Spaced Retention) — COMPLETED ✅
*Provides a dedicated, guilt-free space to review past concepts and maintain mastery.*

- **User Actions**:
  - Any completed beat or chapter has a **"Mark for Revision"** button.
  - Optional quick intervals: *Review in 3 days*, *Review in 1 week*, or *Keep in Revision Shelf*.
- **Revision View**:
  - A clean, distinct tab or shelf in Flow: **"Revision Shelf"**.
  - Lists topics you flagged for review with segmented view: **Due Today** vs **All in Shelf**.
  - Reviewing a topic logs a revision checkmark, advances stability ($2.2\times$), and contributes to study streak 🔥.
  - Completely separated from your new daily learning so you never feel overwhelmed.
- **Acceptance Criteria**:
  - Marking a completed topic places it in the Revision Shelf.
  - Reviewing it logs revision activity without altering curriculum progress.

---

### Feature 6: YouTube Timestamps & Community Comments Chapter Extraction — COMPLETED ✅
*Extracts semantic topics from descriptions and comments for long single-video courses.*

- **Extractor Engine**:
  - Automatically parses description timestamps (`00:00`, `12:45`) into structured chapters.
  - **Comment Fallback**: If description has no timestamps (or `< 2` segments), parses pinned, creator-hearted, and top community comments to extract timestamps and topic titles.
  - Broad regex support handles multiline lists, inline lists with delimiters (`•`, `|`, `~`), and line-ending timestamps (`Title: 00:00`).
  - Zero-drop guarantee: Clamps early start offsets ($\le 90$s) to 0, accurately sets deep-link URLs (`&t=Xs`), and derives proportional effort weights.
- **Acceptance Criteria**:
  - Ingesting a long video with comment timestamps breaks it down into individual chapters with titles and durations.
  - 100% verified across 196 comprehensive automated tests.

---

### Feature 7: In-App GitHub Releases Updater & Modal Sheet — COMPLETED ✅
*Self-contained in-app updater from Settings with glassmorphic modal and native Android installer.*

- **Update Pipeline**:
  - Checks `https://api.github.com/repos/ImSurajx/rythem-app/releases/latest`.
  - Robust SemVer parsing (`SemVer.parse`) handles build numbers (`v1.0.1+2`), prereleases, and version comparisons.
- **Glassmorphic Modal Sheet**:
  - Displays version bump badges (`v1.0.1` ➔ `v1.0.2`), APK file size, publication date, and scrollable markdown changelog.
  - **Streaming Progress**: Real-time progress bar showing download percentage, downloaded MBs, and transfer speed.
- **Native Android Installer**:
  - Zero-dependency MethodChannel in `MainActivity.kt`.
  - Checks `canRequestPackageInstalls()` permission and routes to Android Settings if needed.
  - Launches Android Package Installer via `FileProvider` with `application/vnd.android.package-archive`.
  - Multiplatform fallback opens release or APK download URL in external browser via `url_launcher`.
- **Acceptance Criteria**:
  - Tapping "Check for Updates" in Settings opens the modal.
  - Downloading streams the APK with a live progress bar.
  - Seamlessly prompts Android installation flow.
  - 100% verified across 217 automated tests.

---

## 🚀 Execution Strategy
We will execute strictly **one feature at a time**:
1. Implement the feature.
2. Run automated unit/widget tests.
3. Verify on device.
4. Obtain user sign-off before proceeding to the next feature.
