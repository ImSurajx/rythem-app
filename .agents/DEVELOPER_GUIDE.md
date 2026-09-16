# Rythem Developer & Agent Guide

> **Quick Reference**: Practical guidelines, testing workflows, common development tasks, and coding conventions for agents working on Rythem.

---

## 1. Quick Development Commands

Always run these commands from the repository root:

```bash
# Install and update dependencies
flutter pub get

# Static code analysis (must have 0 errors and 0 warnings)
flutter analyze

# Run the complete automated test suite (123+ tests)
flutter test

# Run a specific test suite
flutter test test/calendar_graphs_and_delay_test.dart
flutter test test/rapid_toggle_sync_test.dart
flutter test test/user_playlists_ingestion_test.dart

# Build production Android APK
flutter build apk --release
```

---

## 2. Core Architectural Patterns

### A. Repositories Pattern
All database operations pass through specialized repositories in `lib/core/database/repositories/`:
- `RoadmapRepository`: CRUD operations for curriculum tracks (`DatabaseTables.roadmaps`).
- `ChapterRepository`: Chapter grouping with sequential `sort_order` (`DatabaseTables.chapters`).
- `BeatRepository`: Beat management, completion toggling, effort weights (`DatabaseTables.beats`).
- `BeatLogRepository`: Historical completion logs and streak calculations (`DatabaseTables.beatLogs`).
- `AppSettingsRepository`: Key-value configuration storage (`DatabaseTables.appSettings`).

Never execute arbitrary raw SQL queries directly in UI widgets. Always route database access through these repositories.

### B. State Management Pattern
- The root state of the app is managed in `_DesignSystemShowcaseScreenState` in `lib/main.dart`.
- The app uses four primary navigation tabs rendered inside a performance-optimized `FadeIndexedStack`:
  1. `FlowScreen` (Index 0): The daily focus, active mission, and revision dashboard.
  2. `ExploreScreen` (Index 1): Full track catalog, chapter accordions, and ingestion modal.
  3. `MetricsScreen` (Index 2): Habit streak calendar and multi-mode performance charts.
  4. `SettingsTab` (Index 3): Appearance, 7-day study rhythm, local AI manager, and data backup.
- Intra-screen sub-states (such as expansion accordions, scrubber tooltips, and month navigation) are handled via standard Flutter `StatefulWidget` states with explicit haptic feedback (`HapticFeedback.lightImpact()` / `selectionClick()`).

### C. In-Flight Toggle Synchronization
When a beat is toggled in either the Flow tab or Explore tab:
1. The shell records the intent in `_pendingBeatToggles[beatId]`.
2. The asynchronous SQLite write executes (`_beatRepo.toggleBeatCompletion()`).
3. `_scheduleDebouncedReload(80)` waits for concurrent user interactions to settle, reads the fresh SQLite state, and re-computes `PacingBudget`.
4. While the reload is pending, UI widgets overlay `_pendingBeatToggles` to prevent temporary flickering or read clobbering.

---

## 3. Liquid Glass UI Design Standards

All UI screens must adhere to the design system defined in `lib/core/theme/` and `lib/core/widgets/`:

1. **Frosted Surfaces (`GlassCard`)**:
   - Use `GlassCard` for cards and content groups.
   - Borders: Subtle gradient specular highlight (`RythemColors.glassBorder` and `glassBorderHighlight`).
   - Corners: Rounded with standard radius `BorderRadius.circular(16)` or `(12)`.

2. **Typography (`RythemTypography`)**:
   - Use predefined Inter font tokens:
     - `headlineLarge`, `headlineMedium`, `titleMedium`, `bodySmall`, `labelSmall`, `caption`.
   - Never use ad-hoc raw `TextStyle` when a token exists.

3. **Dark & Light Theme Parity**:
   - Ensure every new component supports both `RythemColors.dark` and `RythemColors.light`.
   - Contrast check: Ensure secondary text has sufficient contrast in both themes.

4. **Rendering Performance Safeguards**:
   - Wrap heavy custom painters or static visual elements in `RepaintBoundary`.
   - Do NOT place `BackdropFilter` inside dynamically scrolling list items.

---

## 4. Testing & Verification Checklist

Before finishing any task or committing changes:

1. [ ] **Clean Analysis**: Run `flutter analyze` and ensure **0 issues found**.
2. [ ] **Pass All Tests**: Run `flutter test` and ensure **100% of tests pass**.
3. [ ] **Clean State Preservation**: Verify that no dummy sample roadmaps, fake beat counts, or simulated lag buttons were left in the codebase.
4. [ ] **Signed Commits**: Always commit with `git commit -s -m "..."`.
5. [ ] **Changelog**: Update [CHANGELOG.md](file:///Users/itsurajx/Developer/rythem-app/CHANGELOG.md) when adding features or adjusting behaviors.
