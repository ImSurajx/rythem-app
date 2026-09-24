# Feature 2 Implementation Plan: "Complete in Parts" & Multi-Part Task Splitting

Allow users to conquer 2-hour+ videos and multi-week projects by splitting any task into $N$ parts ($N \ge 2$) across multiple days, registering daily streak and activity on each part completed.

---

## User Review Required

> [!IMPORTANT]
> **Daily Streak & Activity Invariant**:
> When a user marks "Part 1 of 2" completed today:
> 1. An activity entry is logged into `beat_logs` with today's date $\rightarrow$ **today's study streak is preserved and incremented!** 🔥
> 2. The beat remains in pending status (`isCompleted == false`) with `completedParts: 1` so Part 2 is ready for tomorrow or later.
> 3. The beat's remaining effort in Pacing calculations automatically adjusts to 50% ($1.0$ effort remaining out of $2.0$).
> 4. Only when all parts are finished (`completedParts == totalParts`) is the beat marked fully complete (`isCompleted = true`).

---

## Proposed Changes

### 1. Database Schema & Migration (v2 $\rightarrow$ v3)

#### [MODIFY] [tables.dart](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/tables.dart)
- Add column constants to `BeatColumns`:
  - `static const String totalParts = 'total_parts';`
  - `static const String completedParts = 'completed_parts';`

#### [MODIFY] [database_service.dart](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/database_service.dart)
- Bump `_databaseVersion` from `2` to `3`.
- In `_onCreate`: Add `${BeatColumns.totalParts} INTEGER NOT NULL DEFAULT 1,` and `${BeatColumns.completedParts} INTEGER NOT NULL DEFAULT 0,` to `DatabaseTables.beats` table creation.
- In `_onUpgrade`: Add migration branch for `oldVersion < 3`:
  ```sql
  ALTER TABLE beats ADD COLUMN total_parts INTEGER NOT NULL DEFAULT 1;
  ALTER TABLE beats ADD COLUMN completed_parts INTEGER NOT NULL DEFAULT 0;
  ```

---

### 2. Core Models & Pacing Calculator

#### [MODIFY] [beat_entity.dart](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/models/beat_entity.dart)
- Add `final int totalParts;` (default `1`)
- Add `final int completedParts;` (default `0`)
- Update `copyWith`, `toMap`, and `fromMap` (with safe fallback defaults `1` and `0` for backwards compatibility with existing backups and databases).
- Add helper getters:
  - `bool get isMultiPart => totalParts > 1;`
  - `double get partProgress => totalParts > 0 ? (completedParts / totalParts).clamp(0.0, 1.0) : 0.0;`
  - `int get remainingParts => (totalParts - completedParts).clamp(0, totalParts);`

#### [MODIFY] [pacing_calculator.dart](file:///Users/itsurajx/Developer/rythem-app/lib/core/pacing/services/pacing_calculator.dart)
- Update `calculateRemainingEffort`:
  ```dart
  if (!b.isCompleted) {
    if (b.totalParts > 1 && b.completedParts > 0) {
      final fraction = (b.totalParts - b.completedParts).clamp(0, b.totalParts) / b.totalParts;
      sum += b.effortWeight * fraction;
    } else {
      sum += b.effortWeight;
    }
  }
  ```

---

### 3. Repositories

#### [MODIFY] [beat_repository.dart](file:///Users/itsurajx/Developer/rythem-app/lib/core/database/repositories/beat_repository.dart)
- Add `updateBeatParts(String beatId, {required int totalParts})`:
  - Updates `total_parts = totalParts`, clamps `completed_parts` if greater than new total.
  - Updates `is_completed = (completedParts >= totalParts) ? 1 : 0`.
  - Emits `DatabaseEventType.beatUpdated`.
- Add `incrementBeatPart(String beatId, {DateTime? completedAt})`:
  - Increments `completed_parts += 1`.
  - If `completed_parts >= total_parts`: sets `is_completed = 1` and `completed_at = now`.
  - Always logs study activity into `beat_logs` with `completed_date = todayDateStr` to preserve streaks!
  - Emits `DatabaseEventType.beatToggled`.
- Add `decrementBeatPart(String beatId)`:
  - Decrements `completed_parts = max(0, completed_parts - 1)`.
  - If `is_completed` was true, reverts to `is_completed = 0` and `completed_at = null`.
  - Removes the latest part log from `beat_logs`.
  - Emits `DatabaseEventType.beatToggled`.

---

### 4. UI Components

#### [NEW] [split_task_sheet.dart](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/split_task_sheet.dart)
- Frosted glass bottom sheet modal:
  - Header: Lesson Title + *"Complete in Parts"* badge.
  - Subtitle: *"Split this lesson into multiple study sessions or days."*
  - Quick Presets:
    - **2 Parts** (2 sessions / 50% each)
    - **3 Parts** (3 sessions / 33% each)
    - **4 Parts** (4 sessions / 25% each)
  - Custom stepper: `[-]  [ X Parts ]  [+]` (2 to 10 parts).
  - If beat is already multi-part:
    - Current progress indicator: `Part X of Y completed`.
    - **"Reset to Single Task (1 Part)"** button.
  - **Confirm / Save Split** glass button.

#### [MODIFY] [chapter_accordion.dart](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/widgets/chapter_accordion.dart) (and `BeatTile`)
- In `BeatTile`:
  - Add callbacks:
    - `final VoidCallback? onSplit;`
    - `final VoidCallback? onIncrementPart;`
    - `final VoidCallback? onDecrementPart;`
  - Visuals for multi-part tasks:
    - Renders a multi-part segment bar or chip:
      - e.g. `Part 1 / 2 completed` with miniature glass progress segments `[===][---]`.
    - Checkbox interaction:
      - If `beat.isMultiPart` and `beat.completedParts < beat.totalParts`:
        - Shows a partial progress ring/badge `${beat.completedParts}/${beat.totalParts}`.
        - Tapping increments part (`onIncrementPart`), triggers haptic feedback, and toast: *"Part 1 completed! Streak updated 🔥"*.
      - If all parts complete or single part: behaves as standard checkmark toggle.
    - Adds a **"Split Task"** button (`call_split_rounded`) to open `SplitTaskSheet`.

#### [MODIFY] [flow_screen.dart](file:///Users/itsurajx/Developer/rythem-app/lib/features/flow/flow_screen.dart)
- Pass `onSplit`, `onIncrementPart`, and `onDecrementPart` down to `BeatTile`.
- Today's Focus card displays partial completion status (`Part 1 of 2 Complete • In Progress`).

#### [MODIFY] [roadmap_detail_screen.dart](file:///Users/itsurajx/Developer/rythem-app/lib/features/explore/roadmap_detail_screen.dart) & [main.dart](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart)
- Wire `onSplit`, `onIncrementPart`, and `onDecrementPart` across `RoadmapDetailScreen` and `FlowScreen`.

---

## Verification Plan

### Automated Tests
Create dedicated test suite `test/multi_part_task_test.dart`:
1. **Schema & Migration Test**:
   - Verify DB migration from v2 to v3 creates `total_parts` and `completed_parts` with defaults 1 and 0.
2. **Task Splitting Unit Test**:
   - Split a 2.0 effort beat into 2 parts.
   - Verify `totalParts == 2`, `completedParts == 0`, `isMultiPart == true`.
3. **Streak & Part Completion Test**:
   - Complete Part 1:
     - Verify `completedParts == 1`.
     - Verify `isCompleted == false` (remains active for Part 2).
     - Verify entry added in `beat_logs` for today's date.
     - Verify `BeatLogRepository.getCurrentStreak() >= 1`.
4. **Pacing Effort Calculation Test**:
   - Verify `calculateRemainingEffort` drops from 2.0 to 1.0 when 1 of 2 parts is completed.
5. **Final Part Completion Test**:
   - Complete Part 2:
     - Verify `completedParts == 2`.
     - Verify `isCompleted == true` and `completedAt != null`.
     - Verify `calculateRemainingEffort == 0.0`.
6. **Reset / Decrement Test**:
   - Reset multi-part task back to 1 part or decrement parts.
7. **Regression Suite**:
   - Run `flutter analyze` (0 errors).
   - Run full `flutter test` (all 159+ tests pass).
