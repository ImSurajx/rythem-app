# Implementation Plan: Feature 3 — Dynamic Tracker Customization (Custom Subjects, Chapters, Topics & Strict Mentor-Order Append)

## Problem Statement & User Requirements
As articulated by the user:
> *"user can edit tracker too, like if user want to add any topic or create a custom chapter or custom subject so user can do or want to add a topic inside chapter that could also be possible"*
> *"we have to always go with mentor order still the user add anything will be going to place at the bottom of that subject chapter or topic like that last thing of that tracker & if user add multiple so earlier one is first after that the later one is second ex if adding item sequence is 1,2,3 it will be place in tracker, mentor, 1, 2, 3"*

### Guiding Principles & Invariants
1. **Strict Mentor-First Ordering Invariant**:
   - The mentor's original pedagogical sequence is sacred and remains first.
   - Any custom topic added by the user inside a chapter is placed strictly at the **bottom** of that chapter.
   - Any custom chapter added to a subject is placed strictly at the **bottom** of that subject's chapter list.
   - If a user adds multiple custom items sequentially (1, 2, 3), they must appear in exact chronological order: `[mentor_1, mentor_2, ..., mentor_N, user_1, user_2, user_3]`.
2. **First-Class Tracker Citizens**:
   - User-added beats seamlessly integrate into all existing systems:
     - Can be queued into Today's Focus (Feature 1).
     - Can be split into multiple parts (Feature 2).
     - Part completion and task completion advance and preserve daily streaks.
     - Pacing calculations automatically adapt to user-added effort weights.
3. **Liquid Glass Aesthetic & Seamless UX**:
   - Lightweight, non-intrusive frosted glass creation sheets (`AddTopicSheet`, `AddChapterSheet`).
   - One-tap "+ Add Topic" button at the bottom of each chapter accordion.
   - Prominent "+ Add Chapter" glass button at the bottom of the subject detail screen.
   - Options to edit/rename and delete custom items.

---

## Architecture & Proposed Changes

### 1. Database & Domain Models

#### A. Chapters (`lib/core/database/repositories/chapter_repository.dart`)
- Add method `getNextSortOrder(String roadmapId)`:
  - Queries `MAX(sort_order)` for the roadmap.
  - Returns `(max ?? -1) + 1` to guarantee appending at the bottom.
- Add `updateChapter(ChapterEntity chapter)` to support renaming.

#### B. Beats (`lib/core/database/repositories/beat_repository.dart`)
- Add method `getNextSortOrderForChapter(String chapterId)`:
  - Queries `MAX(sort_order)` for beats in that chapter.
  - Returns `(max ?? -1) + 1` to guarantee appending at the bottom.
- Ensure `createBeat` and `updateBeat` properly notify `DatabaseEventBus` with `DatabaseEventType.beatCreated` and `DatabaseEventType.beatUpdated`.

---

### 2. UI Components & Creation Modals

#### A. `AddTopicSheet` (`lib/features/explore/widgets/add_topic_sheet.dart`)
- Frosted liquid glass modal bottom sheet to create or edit a topic:
  - **Title Field**: auto-focused text field with clean glass styling.
  - **Chapter Selector**: dropdown/chips if opened from root, or pre-selected if opened from a specific chapter.
  - **Estimated Effort / Duration**: quick selector chips (30 min / 0.5h, 1h, 1.5h, 2h, 3h+).
  - **Optional Resource Link**: text field for URL (YouTube, documentation, GitHub, blog post, or article).
  - **Initial Parts**: selector to optionally create as multi-part immediately (1 to 4 parts).
  - **Save Action**: validates title, computes next sort order, creates `BeatEntity`, and provides haptic feedback.

#### B. `AddChapterSheet` (`lib/features/explore/widgets/add_chapter_sheet.dart`)
- Frosted glass modal bottom sheet:
  - **Chapter Title Field**: e.g., "System Design Patterns", "Advanced Optimization".
  - **Save Action**: computes next chapter sort order, creates `ChapterEntity`, appends to roadmap.

#### C. `ChapterAccordion` Enhancements (`lib/features/explore/widgets/chapter_accordion.dart`)
- Add `onAddTopic: (ChapterEntity chapter) => void` callback.
- Add `onEditTopic: (BeatEntity beat) => void` and `onDeleteTopic: (BeatEntity beat) => void` callbacks.
- Add `onEditChapter: (ChapterEntity chapter) => void` and `onDeleteChapter: (ChapterEntity chapter) => void` callbacks.
- Render a sleek "+ Add Topic to [Chapter Title]" glass button at the bottom of the beat list inside the expanded accordion.
- Show an options menu (3-dots or edit icon) for editing or deleting user-created beats/chapters.

#### D. `RoadmapDetailScreen` Enhancements (`lib/features/explore/roadmap_detail_screen.dart`)
- Add "+ Add Chapter" button at the bottom of the chapters list.
- Wire `AddTopicSheet` and `AddChapterSheet` modals.
- Reload state reactively upon creation/edit/deletion.

#### E. `FlowScreen` & `main.dart`
- Wire event bus and refresh handlers so any newly added topic or chapter appears in Flow and Track views instantaneously without full app reload.

---

## Mathematical Ordering Proof
Given a chapter with $M$ mentor beats indexed $i \in \{0, 1, \dots, M-1\}$ with sort orders $S_{mentor} = \{s_0, s_1, \dots, s_{M-1}\}$ where $s_0 < s_1 < \dots < s_{M-1}$.

When a user adds sequential custom topics $u_1, u_2, \dots, u_k$ at timestamps $t_1 < t_2 < \dots < t_k$:
- $s(u_1) = \max(S_{mentor}) + 1$
- $s(u_2) = \max(S_{mentor} \cup \{s(u_1)\}) + 1 = s(u_1) + 1$
- $s(u_k) = s(u_{k-1}) + 1$

Since query ordering is `ORDER BY sort_order ASC, created_at ASC`:
$$\forall i \in \{0, \dots, M-1\}, \forall j \in \{1, \dots, k\}: \quad s_i < s(u_1) < s(u_2) < \dots < s(u_k)$$

Therefore, mentor items are strictly first, user items are strictly appended at the bottom, and multiple user items are ordered chronologically.

---

## Verification Plan

### Automated Test Suite: `test/tracker_customization_test.dart`
1. **Append Ordering Test**:
   - Seed chapter with 3 mentor beats (sortOrder 0, 1, 2).
   - Add custom beat 1, then custom beat 2, then custom beat 3.
   - Query beats from SQLite and assert exact order: `[mentor_0, mentor_1, mentor_2, custom_1, custom_2, custom_3]`.
2. **Custom Chapter Append Test**:
   - Seed roadmap with 2 chapters (sortOrder 0, 1).
   - Add custom chapter.
   - Assert custom chapter sortOrder is 2 and appears at the end.
3. **Pacing Integration Test**:
   - Assert `calculateRemainingEffort` increases accurately when a 2.0 effort custom beat is added.
4. **Today's Focus & Part Completion Test**:
   - Queue custom beat into Today's Focus.
   - Split custom beat into 2 parts.
   - Increment part 1: assert streak advances and effort reduces.
5. **Edit & Delete Test**:
   - Edit custom beat title and resource URL.
   - Delete custom beat and chapter and verify cascade cleanup.

### Regression Test Suite
- Run `flutter analyze` (0 errors/warnings).
- Run `flutter test -j 1` across all 37 test suites.
