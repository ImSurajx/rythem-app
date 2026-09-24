# Feature 5 Implementation Plan: Clean Revision Shelf (Spaced Retention)

> **Goal**: Provide students with a dedicated, guilt-free Revision Shelf in the Flow Screen to maintain long-term memory mastery without contaminating new daily learning, creating artificial backlog debt, or modifying curriculum progression.

---

## 1. Architectural Philosophy & Invariants

1. **Guilt-Free & Discrete**:
   - The Revision Shelf is completely separated from Today's Focus Mission.
   - Topics placed in the Revision Shelf **NEVER** force phantom tasks into Today's Focus or trigger "behind schedule" warnings.
2. **True Spaced Repetition**:
   - Students can mark any completed lesson or topic for revision with quick interval presets:
     - **In 3 Days** ($t + 3d$) — Ideal for initial memory stabilization.
     - **In 1 Week** ($t + 7d$) — Ideal for weekly retention blocks.
     - **Keep in Shelf** (Indefinite) — Available in the shelf anytime for self-paced review.
3. **Mastery Verification Without Curriculum Loss**:
   - Reviewing a topic logs a revision completion checkmark, updates its `lastRevisedAt` timestamp, increments `revisionCount`, and logs to `beat_logs` (contributing to today's study streak 🔥).
   - Curriculum completion remains $100\%$ untouched (`beat.isCompleted` stays `true`).

---

## 2. Proposed Changes

### A. Data Models & SQLite Persistence
#### `lib/core/revision/models/revision_item.dart`
- Add `scheduledReviewDate` (`DateTime?`).
- Add `intervalDays` (`int?`).
- Add getter `bool get isDueToday`:
  - Returns `true` if `scheduledReviewDate == null` (ready on demand) OR `scheduledReviewDate! <= DateTime(now.year, now.month, now.day, 23, 59, 59)`.
- Update `toMap`, `fromMap`, `toJson`, `fromJson`, and `copyWith`.

#### `lib/core/revision/services/revision_service.dart`
- `addToRevisionShelf({required BeatEntity beat, required String roadmapTitle, int? intervalDays, String? note})`:
  - Calculates `scheduledReviewDate = intervalDays != null ? today.add(Duration(days: intervalDays)) : null`.
  - Saves in SQLite `app_settings` under `'revision_system_records'`.
- `removeFromRevisionShelf(String beatId)`:
  - Removes beat from revision shelf.
- `getRevisionShelfItems()`:
  - Returns all active items in the shelf.
- `markTopicRevised`:
  - Updates `lastRevisedAt = DateTime.now()`, logs activity in `beat_logs`, expands stability days ($S_{new} = S_{prev} \times 2.2$).

---

### B. UI Components

#### `lib/features/flow/widgets/mark_revision_sheet.dart`
- Frosted liquid glass modal bottom sheet shown when tapping **"Mark for Revision"** on any completed beat:
  - Header: Topic title, course name.
  - Interval selection cards:
    - ⚡ **In 3 Days** ("Reinforce while fresh")
    - 📅 **In 1 Week** ("Weekly retention cycle")
    - 📦 **Keep in Shelf** ("No deadline • Practice anytime")
  - Optional note input ("Add personal friction or memory notes...").
  - "Add to Revision Shelf" button with haptic feedback.

#### `lib/features/flow/widgets/revision_shelf_card.dart`
- Frosted liquid glass card in Flow Screen:
  - Collapsible header: **REVISION SHELF** with badge count (e.g. `3 Topics`).
  - Segmented toggle: **Due Today** | **All In Shelf (N)**.
  - Clean todo list of revision items:
    - Custom checkmark (checking off completes revision for today and marks with strikethrough).
    - Topic title, roadmap title, and strength indicator badge (e.g. `WEAK`, `1x REVISED`, `MASTERED 🏆`).
    - Due countdown pill: `Due Today`, `In 3d`, `In 1w`, `On Demand`.
    - 1-tap "Unshelf" action to remove once mastered.
  - Clean empty state when 0 topics are in shelf, with optional AI memory decay scan.

#### `lib/features/explore/widgets/chapter_accordion.dart` & `BeatTile`
- In `BeatTile`:
  - When `beat.isCompleted == true`:
    - Surfacing the **"Mark for Revision"** button with bookmark icon.
    - If already on the shelf, displays highlighted purple bookmark icon (`In Revision Shelf`).
  - Wire callback `onMarkForRevision`.

#### `lib/features/flow/flow_screen.dart` & `lib/main.dart`
- In `flow_screen.dart`:
  - Replace/enhance `DailyRevisionBoard` with `RevisionShelfCard`.
  - Pass `onAddToRevisionShelf`, `onRemoveFromRevisionShelf`, and `onMarkRevised`.
- In `main.dart`:
  - Handle `_handleAddToRevisionShelf(BeatEntity beat, {int? intervalDays, String? note})`.
  - Handle `_handleRemoveFromRevisionShelf(String beatId)`.
  - Handle `_handleMarkRevised(RevisionItem item)`.
  - Load shelf items into state and update reactively.

---

## 3. Verification & Testing Plan

1. **Unit Tests** (`test/revision_shelf_test.dart`):
   - Adding a beat to revision shelf sets scheduled date accurately for 3 days, 1 week, and indefinite shelf.
   - `isDueToday` getter correctly identifies items due today vs scheduled in the future.
   - Checking off a revision item logs activity in `beat_logs` without resetting `beat.isCompleted`.
   - Removing an item purges it from the shelf.
2. **Widget Tests** (`test/revision_shelf_test.dart`):
   - `BeatTile` shows bookmark / revision button on completed beats.
   - `MarkRevisionSheet` renders interval presets and triggers callback with selected days.
   - `RevisionShelfCard` renders items, toggles between Due Today and All Shelf, and supports revision checkmarks.
3. **Full Regression & Static Analysis**:
   - Run `flutter analyze` to ensure 0 errors and 0 warnings.
   - Run `flutter test` across all test suites to ensure 100% pass rate.
