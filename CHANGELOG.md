# Release

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
