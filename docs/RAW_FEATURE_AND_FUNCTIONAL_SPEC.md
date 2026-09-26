# Rythem: Raw Product & Functional Feature Specification

> **Document Type**: Pure Functional & Technical Feature Inventory  
> **Audience**: Product Designers & System Architects  
> **Note**: This document contains **zero visual design, layout, or styling instructions**. Visual hierarchy, page layouts, navigation patterns, color systems, and component aesthetics are 100% at the discretion of the designer.

---

## 1. Product Purpose & Functional Overview

Rythem is a **local-first curriculum tracker, adaptive pacing engine, and study manager** for self-directed learners tackling large technical subjects (e.g., Computer Science, System Design, Data Structures & Algorithms, Machine Learning).

### The Functional Differentiator: Adaptive GPS Pacing
Unlike standard todo apps that generate growing piles of "overdue" items when days are missed, Rythem operates like a GPS navigation system:
- It tracks the user's **actual study speed** (rolling minutes studied per day).
- When a deadline is set, it calculates the **daily minutes required** to finish on time.
- If days are missed, it **dynamically recalculates remaining daily workloads or suggests updated completion dates** without accumulating backlog debt or red alert flags.

---

## 2. Core Data Entities (Information That Must Be Represented)

Every screen or view designed will draw from these core entities:

### Entity 1: Track (Roadmap)
A high-level subject or course (e.g., "DSA with Python", "MIT 6.006").
- **ID**: Unique identifier.
- **Title**: String (e.g., "Full-Stack System Design").
- **Description / Category**: Subject domain (e.g., "Computer Science", "Backend", "AI").
- **Start Date**: Date when learning began or will begin.
- **Target Deadline**: Optional goal completion date.
- **Total Chapters**: Count of modules inside the track.
- **Total Beats**: Total count of individual lessons.
- **Completed Beats**: Count of finished lessons.
- **Progress Ratio**: Percentage (0.0 to 1.0).
- **Total Duration**: Sum of all lesson video/reading durations (in minutes/hours).
- **Remaining Duration**: Total duration minus completed duration.

### Entity 2: Chapter (Module)
A thematic grouping of lessons within a Track (e.g., "Binary Search Trees", "Dynamic Programming").
- **ID**: Unique identifier.
- **Track ID**: Parent track reference.
- **Title**: String.
- **Sequence Index**: Position in the syllabus (0, 1, 2...).
- **Total Lessons**: Count of lessons in this chapter.
- **Completed Lessons**: Count of completed lessons in this chapter.
- **Chapter Duration**: Sum of lesson durations in this chapter.

### Entity 3: Beat (Lesson / Task)
The atomic unit of study. Usually represents one video lecture, a textbook section, or an article.
- **ID**: Unique identifier.
- **Chapter ID & Track ID**: Parent references.
- **Title**: String (e.g., "Inverting a Binary Tree").
- **Duration Minutes**: Integer (e.g., 22 minutes).
- **Sequence Index**: Position in chapter.
- **Resource URL**: Direct link (e.g., YouTube video URL, article link, local document).
- **Status**: Completed (`true`/`false`).
- **Completion Timestamp**: DateTime when checked off.
- **Multi-Part Index**: If split by the user, indicates `Part X of Y` (e.g., Part 1 of 2).
- **Is Confusing / Priority**: Flag indicating the user requested reinforcement on this topic.
- **Notes**: User-written markdown notes or key takeaways.
- **Is Delayed**: Flag indicating user explicitly postponed this lesson.

### Entity 4: Pacing Budget (GPS Velocity Telemetry)
Dynamically calculated numbers reflecting the user's speed and trajectory for a track.
- **Target Date**: User's chosen goal deadline.
- **Predicted Finish Date**: Statistically projected completion date based on actual 7-day velocity.
- **Days Remaining**: Calendar days until target date.
- **Required Daily Minutes**: Minutes of study needed per active day to hit the deadline.
- **Current Moving Velocity**: 7-day harmonic mean of study minutes completed per day.
- **Pacing State**:
  - `ON_TRACK`: Current velocity is sufficient to hit the deadline.
  - `BEHIND_SCHEDULE / ADAPTED`: Current velocity will miss the deadline by N days; recalculation required.
  - `OPEN_PACE`: No deadline set; self-paced learning.
  - `COMPLETED`: All lessons finished.
  - `UPCOMING`: Track starts in the future.
- **Catch-up Delta**: Extra minutes per day needed or extra calendar days needed to glide the deadline.

### Entity 5: Streak & Activity Matrix
Logs of user activity over time.
- **Active Streak Count**: Consecutive active study days (integer).
- **Date Activity Map**: A key-value record mapping each date (`YYYY-MM-DD`) to total beats completed or minutes logged.
- **Weekly Slice**: Monday-to-Sunday matrix of activity for the active or selected week.

### Entity 6: Spaced Repetition Item (Retention Shelf)
Topics scheduled for quick active recall review.
- **Beat Reference**: Topic title, parent track, duration.
- **Interval Tier**: Current retention stage (`Day 1`, `Day 3`, `Day 7`, `Day 14`, `Day 30`).
- **Due Date**: Date when review is recommended.
- **Review Count**: How many times successfully reviewed.

### Entity 7: System Settings & Local Engine
- **Appearance Preference**: System / Dark / Light.
- **7-Day Study Intensity Schedule**: User-configured minutes/day allocation for Monday through Sunday (e.g., Mon=30m, Sat=120m).
- **Local AI Model Status**: Compact Tier (0.5B) or Balanced Tier (1.5B) download state (Not Downloaded, Downloading [progress %], Ready, Error).
- **Backup Configuration**: Backup file location, auto-backup frequency (Daily, Weekly, On Completion).
- **App Version**: Current installed SemVer string and available update status.

---

## 3. Exhaustive Functional Capabilities Directory

### Capability 1: Curriculum Ingestion (Importing Material)
1. **YouTube Playlist Importer**:
   - Accepts YouTube playlist URL.
   - Parses video metadata: titles, durations, video IDs, channel info.
   - Handles massive playlists (200+ videos).
   - Generates preview before committing: total video count, total duration, chapter groupings.
2. **Syllabus / Markdown Importer**:
   - Accepts raw text, markdown bullet lists, or hierarchical outlines.
   - Extracts module names and nested lesson titles.
3. **Manual Track Creator**:
   - User inputs track name, subject category, and creates chapters/lessons manually.
4. **Deadline & Pacing Setup during Ingestion**:
   - User chooses: (A) Target completion date, or (B) Daily time budget, or (C) Open Pace.
   - System immediately displays expected daily commitment before saving.

---

### Capability 2: Mentor-First Sequence & Alignment
1. **Teacher Order Preservation**:
   - Lessons maintain the exact order taught by the instructor.
2. **Curriculum Gap Detection**:
   - Compares a theoretical syllabus against a practical video playlist.
   - Flags topics that the video series skipped or omitted.
3. **Ambiguity Resolution**:
   - When a video title does not cleanly map to a known syllabus topic, the system flags it as ambiguous with a match confidence score.
   - Allows the user to confirm or reject the match with one tap.

---

### Capability 3: GPS Adaptive Pacing Engine
1. **Real-Time Velocity Tracking**:
   - Every time a lesson is completed, the system recalculates actual velocity.
2. **ETA Projection**:
   - Displays whether the predicted finish date aligns with, precedes, or lags the target deadline.
3. **Adaptive Backlog Recovery (No Red Alarms)**:
   - When a user misses days, the system calculates two frictionless recovery options:
     - **Option 1 (Pace Absorption)**: Add X minutes per remaining day to keep the same deadline.
     - **Option 2 (Deadline Glide)**: Push the target deadline back by Y days to maintain the current daily pace.
4. **Timeline Adjuster**:
   - Interactive deadline adjustment tool: as the user changes dates, required daily minutes update in real time.

---

### Capability 4: Daily Learning Flow & Task Execution
1. **Unabridged Curriculum View**:
   - All chapters and lessons of active tracks are visible in a clean hierarchical structure.
2. **Interactive Check-Off**:
   - Direct completion toggle with immediate persistence and haptic feedback.
3. **Task Splitting**:
   - User can break any long lesson into N parts (e.g., a 90-minute lecture split into Part 1 and Part 2).
   - Tracks completion independently for each part.
4. **Task Delay / Snooze**:
   - Postpone non-critical lessons without deleting them from the curriculum.
5. **Mark as Confusing**:
   - Flag topics that need re-watching or extra practice.
   - Automatically prioritizes the topic in the Spaced Repetition shelf.
6. **Track Filtering**:
   - Ability to view "All Tracks" or filter down to a specific single track.

---

### Capability 5: Distraction-Free Focus Session (Study Mode)
1. **Dedicated Focus View**:
   - Shows active lesson title, track context, and chapter context.
   - Embedded external resource link / video launcher.
   - Built-in study timer (count-up or count-down).
   - Personal notes & key takeaways input field.
   - Previous lesson / Next lesson navigation steppers.
   - Direct "Mark Complete & Continue" action.

---

### Capability 6: Spaced Repetition Memory Shelf
1. **Automatic Intake**:
   - Completed lessons automatically enter the memory retention queue.
2. **Interval Stages**:
   - Surfaces items at 1 day, 3 days, 7 days, 14 days, and 30 days after initial completion.
3. **Quick Review Actions**:
   - `Mark Revised`: Confirms review and promotes the item to the next retention tier.
   - `Reschedule`: Postpones the review to another day.
   - `Unshelf`: Permanently removes the topic from future review prompts.

---

### Capability 7: Study Analytics & Trajectory Reporting
1. **Total Hours & Cumulative Velocity**:
   - Hours studied this week, this month, and all time.
2. **Weekly Intensity Distribution**:
   - Day-by-day breakdown of minutes studied from Monday through Sunday.
3. **Subject Balance Ratio**:
   - Distribution of time across enrolled tracks (e.g., 50% DSA, 30% Backend, 20% Math) to prevent over-studying one topic while neglecting others.
4. **On-Time Finish Probability**:
   - Statistical projection of completing the track before the goal deadline.

---

### Capability 8: Local-First Engine & Privacy Controls
1. **Zero Cloud Dependency**:
   - All curricula, notes, logs, and progress stored entirely in local SQLite on the device.
2. **On-Device AI Models (GGUF LLMs)**:
   - Optional local intelligence engine (MiniCPM / Gemma 0.5B - 1.5B parameters).
   - Download manager with progress percentage, file size, pause/resume, and cancel.
   - Used offline for topic summarization and advanced syllabus gap identification.
3. **Backup & Data Portability**:
   - Instant manual backup export (clean SQLite database + JSON snapshot).
   - Instant restore from backup file.
   - Automated recurring backups (Daily, Weekly, or upon track completion) saved to user-designated storage.
4. **In-App Software Updater**:
   - Checks official releases via SemVer comparison.
   - Downloads and executes native platform installation packages.

---

## 4. Master User Action & Gesture Inventory

This is a complete list of every user action the UI must accommodate:

### Ingestion & Track Management
- [ ] Paste a YouTube playlist link or syllabus text.
- [ ] Preview ingested playlist modules, total duration, and video count.
- [ ] Select or edit Track Start Date.
- [ ] Select or edit Track Target Completion Date.
- [ ] Choose self-paced mode ("Open Pace") without a deadline.
- [ ] Switch active focus between multiple enrolled tracks.
- [ ] Delete or archive an enrolled track.
- [ ] Re-sync an existing track with an updated YouTube playlist.
- [ ] Manually add a new Chapter to an existing track.
- [ ] Manually add a new Beat/Lesson to an existing Chapter.

### Daily Flow & Execution
- [ ] Mark a lesson complete via checkbox / button.
- [ ] Uncheck a completed lesson (undo).
- [ ] Tap a lesson to launch the Focus Session.
- [ ] Launch external video / resource URL in YouTube or browser.
- [ ] Split a long lesson into 2 or more smaller parts.
- [ ] Merge split parts back into a single lesson.
- [ ] Flag a lesson as "Confusing / Needs Practice".
- [ ] Delay / snooze a lesson to the end of the chapter.
- [ ] Confirm an ambiguous video-to-syllabus match recommendation.
- [ ] Reject an ambiguous match recommendation.
- [ ] Filter view between "All Tracks" and individual subjects.
- [ ] Swipe week calendar left/right to view past study history.
- [ ] Tap "Today" to return to current week.

### Spaced Repetition (Revision Shelf)
- [ ] Review topics due today.
- [ ] Mark topic as "Revised" (advances to next interval).
- [ ] Reschedule review topic.
- [ ] Unshelf topic (stop reviewing).

### Pacing Adjustments
- [ ] Expand / collapse the Pacing Telemetry HUD.
- [ ] Open Timeline Adjuster to drag and test new target dates.
- [ ] Accept adaptive recovery recommendation (absorb extra minutes or glide date).

### Focus Mode (Study Screen)
- [ ] Start / Pause study session timer.
- [ ] Type and save personal study notes.
- [ ] Navigate to previous lesson.
- [ ] Navigate to next lesson.
- [ ] Complete lesson and automatically advance.

### Settings & Configuration
- [ ] Switch between Light, Dark, and System appearance.
- [ ] Adjust daily study intensity sliders (Monday through Sunday).
- [ ] Download on-device AI model.
- [ ] Pause / Cancel AI model download.
- [ ] Delete local AI model to free storage.
- [ ] Trigger manual backup export.
- [ ] Choose backup file destination.
- [ ] Trigger backup restore.
- [ ] Configure auto-backup schedule frequency.
- [ ] Check for software updates and trigger install.

---

## 5. System States & Logic Rules

### Pacing States & Formulas
1. **On Track**:
   - `Actual 7-Day Velocity >= Required Daily Velocity`.
   - Communication goal: Reassurance of steady progress.
2. **Pace Adapted (Missed Days / Behind Schedule)**:
   - `Actual Velocity < Required Daily Velocity`.
   - System calculates:
     - `Extra Minutes Needed = (Remaining Total Minutes / Remaining Days) - Actual Velocity`.
     - `Days Slip = (Remaining Total Minutes / Actual Velocity) - Remaining Days`.
   - Communication goal: Calm, actionable choice without guilt or red warning banners.
3. **Open Pace**:
   - Track has no target deadline.
   - Shows total progress percentage and cumulative time spent, with no velocity pressure.
4. **Day 0 / Empty State**:
   - User has zero enrolled tracks.
   - Communication goal: Clear invitation to import first playlist or syllabus.
5. **Today's Goal Met**:
   - User has completed their allocated study minutes or target lessons for today.
   - Communication goal: Sense of completion, celebration, and suggestion to rest.
6. **Curriculum 100% Completed**:
   - All beats marked complete.
   - Communication goal: Milestone achievement celebration and option to archive/export.

---

## 6. End-to-End User Journeys (Jobs to Be Done)

### Journey A: The First-Time Curriculum Setup
1. User opens the app for the first time.
2. User provides their weekly study availability (e.g., 1 hour/day on weekdays, 2 hours/day on weekends).
3. User pastes a 120-video YouTube playlist for "Data Structures & Algorithms".
4. System parses the playlist, generates chapters, and estimates total course duration (e.g., 42 hours).
5. User sets a goal: "I want to finish by June 1st".
6. System calculates and confirms: *"Requires 38 minutes/day across 5 days/week"*.
7. Track is created and ready for daily study.

### Journey B: The Daily Study Session
1. User opens the app in the morning.
2. System displays today's top study queue and current pacing velocity.
3. System alerts user that 2 previous lessons are due for quick Spaced Repetition review.
4. User spends 5 minutes reviewing notes for the 2 revision items and marks them `Revised`.
5. User starts the primary lesson for today, entering Focus Mode with the video link and timer running.
6. User finishes the lesson, writes a quick note, and marks it complete.
7. System updates velocity, lights up today's streak day, and recalculates the finish date.

### Journey C: Life Gets Busy (Adaptive Recovery)
1. User gets sick or busy and cannot study for 4 days.
2. User returns on Day 5.
3. System displays **zero red alert badges** and **zero 20-item overdue backlogs**.
4. Pacing status gently indicates `Pace Adapted`.
5. System offers two clean options:
   - Option 1: *"Add 9 minutes to each remaining day to still finish by June 1st"*.
   - Option 2: *"Keep your same 38 mins/day pace and finish by June 6th"*.
6. User taps Option 2 with one tap. Stress is eliminated, and momentum continues immediately.

---

*This document contains the complete, unadulterated functional specification of Rythem. The designer may invent any UI layout, page structure, design language, or navigation pattern that fulfills these capabilities.*
