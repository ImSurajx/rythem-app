# Implementation Plan: Feature 1 — Core Decoupling & Pure User-Driven "Today's Focus"

## 1. Executive Summary & Problem Statement
Currently, whenever Rythem launches, rolls over to midnight, or restores a backup, `PacingService.computePacingBudget` detects that the `daily_missions` table has no entries for today's date and **automatically walks the pending curriculum queue to force-insert 3 tasks**. 

Furthermore, checking off tasks or restoring a backup triggers race conditions where unwanted phantom tasks auto-spawn or reappear, and the rigid "Evening Unlock" system prevents learners from studying ahead on their own terms.

**Objective of Feature 1**:
Decouple task assignment from automated algorithms. The Flow screen becomes a **pure, user-curated daily focus space**:
1. App launches with **zero auto-generated tasks**.
2. Tasks appear in "Today's Focus" **only when deliberately added by the user**:
   - Via a **"+ Add to Today"** button on any beat in the Roadmap/Chapter view.
   - Via an optional 1-tap **"Queue Next Lesson"** button on the Flow screen.
3. Users can easily remove a task from Today's Focus (`X`) if they change their mind.
4. Completing all chosen tasks shows a peaceful **"All Done for Today!"** celebration with **zero surprise tasks auto-spawning**.
5. Restoring a backup loads pure data with **zero phantom tasks**.
6. "Evening Unlock" arbitrary gating is completely removed.

---

## 2. Architecture Comparison

### Before (Algorithmic Auto-Spawning)
```
App Launch / Restore / Rollover
         │
         ▼
Is daily_missions empty? ──(YES)──► Auto-walk pending queue (forced 3 beats)
         │                                       │
         ▼ (NO)                                  ▼
Keep existing beats ◄────────────────── Insert into SQLite
         │
User checks off beat ──► Re-evaluates queue ──► High risk of auto-spawning extra beats
```

### After (User-Driven Focus)
```
App Launch / Restore / Rollover
         │
         ▼
Read daily_missions for today
         │
         ├─► Empty? ──► Show clean slate: "No tasks queued. Add from track or tap Queue Next."
         │
         └─► Has beats? ──► Display ONLY user-chosen beats
                                   │
User taps "Queue Next Lesson" ────► Finds next sequential incomplete beat ──► Adds to today
User taps "+ Add to Today" (Track)─► Adds chosen beat to today's focus
User taps "Remove" (X) ────────────► Removes beat from today's focus
User completes all chosen beats ──► "All Done for Today!" (Zero auto-spawned tasks)
```

---

## 3. Detailed Component Plan

### A. Database & Repository Layer (`DailyMissionRepository`)
**File**: `lib/core/database/repositories/daily_mission_repository.dart`

1. **`addBeatToTodayMission`**:
   - Signature: `Future<void> addBeatToTodayMission({required String roadmapId, required String date, required String beatId})`
   - Checks if `beatId` is already in today's mission for `roadmapId` on `date`.
   - If not present, finds `max(sortIndex) + 1` and inserts a new row into `daily_missions`.
   - Emits `DatabaseEventType.roadmapUpdated` on `_eventBus`.

2. **`removeBeatFromTodayMission`**:
   - Signature: `Future<void> removeBeatFromTodayMission({required String roadmapId, required String date, required String beatId})`
   - Deletes the specific row `roadmap_id = ? AND date = ? AND beat_id = ?`.
   - Emits `DatabaseEventType.roadmapUpdated` on `_eventBus`.

3. **`getMissionBeatsForDate`**:
   - Keep current inner-join implementation so deleted beats are safely filtered out.

---

### B. Service Layer (`PacingService`)
**File**: `lib/core/pacing/services/pacing_service.dart`

1. **Eliminate the Auto-Spawn Branch in `computePacingBudget`**:
   - In lines 157-185, **remove** `PacingCalculator.walkQueueToFillBudget` auto-assignment.
   - If `todaysBeats` is empty:
     - Check if any beats were completed today (`beatsCompletedToday`). If so, they are displayed (with strikethrough).
     - Otherwise, `todaysBeats = []`. **Do NOT auto-insert anything into `daily_missions`.**
   - If `todaysBeats.isNotEmpty`:
     - Retain user-selected beats.
     - If the user completed bonus beats today, merge them so they show strikethrough.

2. **Add `addBeatToTodayFocus`**:
   ```dart
   Future<void> addBeatToTodayFocus({required String roadmapId, required String beatId}) async {
     final now = DateTime.now();
     final todayDateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
     await _dailyMissionRepo.addBeatToTodayMission(
       roadmapId: roadmapId,
       date: todayDateStr,
       beatId: beatId,
     );
   }
   ```

3. **Add `removeBeatFromTodayFocus`**:
   ```dart
   Future<void> removeBeatFromTodayFocus({required String roadmapId, required String beatId}) async {
     final now = DateTime.now();
     final todayDateStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
     await _dailyMissionRepo.removeBeatFromTodayMission(
       roadmapId: roadmapId,
       date: todayDateStr,
       beatId: beatId,
     );
   }
   ```

4. **Add `queueNextBeatIntoTodayFocus`**:
   - Finds all chapters for `roadmapId` ordered by `sortOrder ASC`.
   - Finds all incomplete beats (`isCompleted == false`) ordered by `chapter.sortOrder ASC, beat.sortOrder ASC, beat.createdAt ASC`.
   - Filters out beats already in today's mission.
   - If an incomplete beat exists, calls `addBeatToTodayFocus` with that beat.
   - Returns the queued `BeatEntity` (or `null` if the entire roadmap is completed).

5. **Remove Evening Unlock & Strict Quota Enforcement**:
   - `isDailyQuotaCompleted`: `true` when `todaysBeats.isNotEmpty` and all beats in `todaysBeats` are `isCompleted == true`.
   - Remove any time-of-day checks that restrict studying ahead.

---

### C. UI Layer (`FlowScreen` & `_TrackTodoListCard`)
**File**: `lib/features/flow/flow_screen.dart`

1. **When Today's Focus is Empty (`todaysBeats.isEmpty`)**:
   - Display a serene, clean state:
     - Icon: `Icons.wb_sunny_outlined` or `Icons.spa_rounded`.
     - Title: *"Your slate is clean for today"*
     - Subtitle: *"Pick specific topics from your roadmap, or tap below to continue where you left off."*
     - Primary Button: **`Queue Next Lesson`** (`Icons.play_arrow_rounded`) $\rightarrow$ calls `queueNextBeatIntoTodayFocus`.
     - Secondary Button: **`Browse Track`** $\rightarrow$ opens the Roadmap detail view.

2. **When Today's Focus Has Tasks (`todaysBeats.isNotEmpty`)**:
   - Render the user's task cards.
   - Each card displays:
     - Checkbox for completion (tapping toggles completion and updates streak).
     - Title, chapter name, duration badge (`~25m`).
     - A subtle remove button (`Icons.close_rounded`) to remove the task from Today's Focus if the user changed their mind.
   - Footer:
     - If all tasks are checked off: Show **"All Done for Today! 🎉"** with an option to `+ Queue Another Lesson` or enjoy the rest of the day.
     - If tasks remain incomplete: Show a secondary `+ Queue Next Lesson` button at the bottom of the list.

---

### D. UI Layer (`RoadmapDetailScreen` & `ChapterAccordion`)
**Files**: 
- `lib/features/explore/roadmap_detail_screen.dart`
- `lib/features/explore/widgets/chapter_accordion.dart`

1. **"+ Today" Action on Beat Tiles**:
   - For pending beats (`isCompleted == false`), add a lightweight action chip or icon:
     - If NOT in today's focus: **`+ Today`** (tapping adds to today's focus and shows a toast *"Added to Today's Focus"*).
     - If ALREADY in today's focus: Shows a subtle active chip **`In Focus`** with option to remove.
2. Direct, frictionless feedback so users can easily build their day while browsing their course.

---

### E. Backup & Restore Invariant
**File**: `lib/features/settings/widgets/backup_restore_card.dart`
- When a backup is restored, the SQLite database is overwritten with the user's exact backup snapshot.
- The app reloads state. Because `computePacingBudget` no longer auto-spawns tasks, the restored state is **100% identical to the snapshot** without phantom tasks appearing.

---

## 4. Verification & Testing Plan

### Automated Test Cases (`test/user_driven_focus_test.dart`)
1. **Fresh Day Launch**:
   - Initialize roadmap with 10 beats.
   - Call `computePacingBudget`.
   - Verify `todaysBeats` is EMPTY (length 0). Zero tasks auto-spawned!
2. **Queue Next Lesson (1-tap)**:
   - Call `queueNextBeatIntoTodayFocus`.
   - Verify `todaysBeats.length == 1` and it is strictly Chapter 1 Beat 1 (`b_0`).
   - Call `queueNextBeatIntoTodayFocus` again.
   - Verify `todaysBeats.length == 2` with `b_0` and `b_1`.
3. **Manual Add from Roadmap**:
   - Call `addBeatToTodayFocus` with Chapter 2 Beat 1 (`b_5`).
   - Verify `todaysBeats` contains `b_5`.
4. **Remove from Today's Focus**:
   - Call `removeBeatFromTodayFocus` with `b_0`.
   - Verify `b_0` is removed from `todaysBeats`, leaving `b_1` and `b_5`.
5. **No Surprise Auto-Spawning on Completion**:
   - Mark `b_1` and `b_5` as completed.
   - Call `computePacingBudget`.
   - Verify `isDailyQuotaCompleted == true`.
   - Verify NO new beats were automatically injected!
6. **Backup / App Reopen Stability**:
   - Simulate closing and reopening app on next day or after restore.
   - Verify `todaysBeats` is clean and no tasks are forced onto the screen.

### On-Device Manual Testing Checklist
- [ ] Open app on phone: verify Flow screen shows clean slate ("Your slate is clean for today").
- [ ] Tap "Queue Next Lesson": verify first lesson appears.
- [ ] Go to Roadmap Detail screen: tap "+ Today" on a topic from Chapter 2: verify it appears in Flow.
- [ ] Complete both tasks: verify "All Done for Today!" card displays with zero phantom tasks appearing.
- [ ] Tap `X` on a task: verify it cleanly leaves Today's Focus.
- [ ] Close and re-open app: verify state is rock-solid and stable.
- [ ] Restore a backup: verify zero phantom tasks are generated.

---

## 5. Rollout Steps for Feature 1
1. **Step 1A**: Implement `addBeatToTodayMission` and `removeBeatFromTodayMission` in `DailyMissionRepository`.
2. **Step 1B**: Decouple `PacingService` (kill auto-walker, add `addBeatToTodayFocus`, `removeBeatFromTodayFocus`, `queueNextBeatIntoTodayFocus`).
3. **Step 1C**: Update `FlowScreen` UI (clean empty state, task cards with `X` remove, and footer buttons).
4. **Step 1D**: Update `ChapterAccordion` with `+ Today` action.
5. **Step 1E**: Run automated test suite and verify 0 analyzer warnings.
6. **Step 1F**: User tests on physical device. Once approved, commit and proceed to Feature 2!
