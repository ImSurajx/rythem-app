# Rythem: Master Feature & Component Design Specification

> **Target Audience**: Product Designers, UI/UX Architects, and Figma Systems Designers.  
> **Purpose**: An exhaustive functional inventory of every feature, component, data point, state, and interaction in Rythem. Use this document as the master blueprint to redesign, rearrange, merge, or create new page layouts and design systems.

---

## 1. Product DNA & Design Goals

### The Core Problem
Most study/todo apps fail learners because:
1. **Checklist Guilt**: When you miss 3 days, standard apps stack 50 red "Overdue" badges. Users feel overwhelmed and quit ("Backlog Debt").
2. **Static Deadlines**: They don't adapt when a topic takes longer than expected.
3. **Disconnected Resources**: Syllabi, YouTube playlists, textbooks, and notes live in 5 different browser tabs.

### Rythem's Core Promise
Rythem is an **Academic GPS and Autonomous Study Coach**:
- It ingests massive curricula (200+ video YouTube playlists, college syllabi) into structured chapters and bite-sized lessons ("Beats").
- It calculates dynamic velocity (minutes per day) and recalculates finish dates without guilt when life happens.
- It provides a distraction-free, liquid glass focus environment with built-in spaced repetition.

### Desired Emotional Response
- **Calm & Deep Focus**: No loud alarmist red banners, aggressive gamification, or cluttered social feeds.
- **Luminous Precision**: Feels like Apple VisionOS or macOS Sonoma — sleek, frosted dark glass with rich ambient aurora lighting refracting through it.
- **Momentum**: Every completed beat immediately reflects in moving velocity, glowing calendar days, and realistic finish projections.

---

## 2. Complete Feature Catalog (The 7 Pillars)

Below is every functional capability the app possesses. Each feature contains specific data inputs, calculations, and UI outputs.

```
┌────────────────────────────────────────────────────────────────────────┐
│                               RYTHEM CORE                              │
├─────────────────┬──────────────────┬─────────────────┬─────────────────┤
│ 1. INGESTION    │ 2. ALIGNMENT     │ 3. PACING (GPS) │ 4. DAILY FLOW   │
│ • YouTube Mega  │ • Mentor Order   │ • Velocity math │ • Unabridged    │
│ • College Syll  │ • Gap Detection  │ • Real-time ETA │ • Streak Matrix │
│ • Video Parsing │ • Jaro-Winkler   │ • Anti-Backlog  │ • Task Splitter │
├─────────────────┼──────────────────┼─────────────────┼─────────────────┤
│ 5. REPETITION   │ 6. ANALYTICS     │ 7. LOCAL ENGINE │ 8. THEME ENGINE │
│ • 1,3,7,14,30d  │ • Velocity Graph │ • Offline SQLite│ • 4 Palettes    │
│ • Daily Shelf   │ • Intensity Map  │ • Local LLM     │ • Aurora Canvas │
│ • Quick Recall  │ • Subject Share  │ • Auto-Backups  │ • Track Auras   │
└─────────────────┴──────────────────┴─────────────────┴─────────────────┘
```

---

### Pillar 1: Curriculum Ingestion & Ingestion Wizard
- **Capabilities**:
  - **YouTube Playlist Ingestion**: Parses public playlists via panel parsing, extracting 200+ video titles, durations, video IDs, and thumbnails.
  - **College Syllabus & Markdown Ingestion**: Parses hierarchical topics, chapters, and nested bullet points.
  - **Curriculum Tree Builder**: Organizes flat lists of videos into natural thematic Modules/Chapters based on numbering, keywords, and structural breaks.
  - **Custom Track Creation**: User sets track title, category/subject, start date, and target completion deadline.
- **Key Data Generated**: Track Entity (ID, Title, Description, Subject, Start Date, Target Date, Created At).

---

### Pillar 2: Mentor-First Alignment & Ambiguity Resolver
- **Capabilities**:
  - **Preserves Teacher Order**: Unlike typical AI that scrambles curricula into arbitrary alphabetical order, Rythem respects the instructor's pedagogical sequence.
  - **Gap Detection & Topic Subtraction**: Compares a syllabus against a YouTube playlist to highlight topics the playlist skipped.
  - **Ambiguity Resolver**: If a video title is ambiguous (e.g., "Lecture 14: Special Case"), the algorithm computes confidence scores and prompts the user with an inline **Confirm / Reject** card.
- **Key Data Generated**: Chapter Entities, Beat Entities (Title, Duration Minutes, Sequence Index, Video URL, Ambiguity Flag, Match Confidence).

---

### Pillar 3: GPS Dynamic Pacing & Anti-Backlog Engine
- **Capabilities**:
  - **Rolling Velocity (Minutes/Day)**: Computes actual 7-day harmonic mean velocity.
  - **Predicted Finish Date (ETA)**: Continuously projects the true completion date based on real user speed vs required speed.
  - **Anti-Backlog Adaptation (`PACE ADAPTED`)**: When a user misses days, Rythem does not pile overdue red warnings. Instead, it re-slices the remaining minutes across remaining days or suggests a painless deadline glide.
  - **Pacing Budgets**: Calculates:
    - Target daily minutes needed to hit deadline.
    - Weekend vs. weekday study intensity allocations.
    - Open Pace mode (for self-paced study without deadlines).
- **Key Data Generated**: `PacingBudget` (isBehindSchedule, targetDate, predictedFinishDate, dailyMinutesNeeded, actualVelocity, isUpcoming, isCompleted).

---

### Pillar 4: Daily Flow & Execution Engine
- **Capabilities**:
  - **Full Unabridged View**: Renders the complete roadmap for active tracks grouped by chapter (no artificial gating or locked levels).
  - **Instant Check-off**: Real-time optimistic checkbox completion with haptic feedback.
  - **Task Splitting**: Allows dividing an intimidating 2-hour lecture into smaller manageable chunks (e.g., "Binary Trees (Part 1/2)").
  - **Delay / Reschedule**: Postpone non-essential lessons without breaking roadmap integrity.
  - **Focus Session (Focus Mode)**: Distraction-free full-screen player with embedded video link, interactive timer, notes editor, and previous/next stepper.
  - **7-Day Streak Calendar**: Tracks consecutive study days with swipeable week-by-week history.
- **Key Data Generated**: `BeatLogEntity` (Beat ID, Completed Timestamp, Time Spent Minutes).

---

### Pillar 5: Spaced Repetition Retention Shelf
- **Capabilities**:
  - **Automatic Graduation**: Completed beats automatically enter the memory shelf.
  - **Review Intervals**: Exponential review schedule: 1 day, 3 days, 7 days, 14 days, 30 days.
  - **Daily Revision Board**: Surfaces items due for recall on the daily dashboard.
  - **Actions**: `Mark Revised` (graduates to next tier), `Reschedule` (snooze), `Unshelf` (stop reviewing).
- **Key Data Generated**: `RevisionItem` (Beat ID, Roadmap ID, Tier Index, Due Date, Last Reviewed Date).

---

### Pillar 6: Analytics & Health Metrics
- **Capabilities**:
  - **Velocity Graph**: Weekly completed beats and minutes studied trend lines.
  - **7-Day Study Intensity Heatmap**: Visualizes study habits across Monday through Sunday.
  - **Subject Balance Distribution**: Compares study time across multiple tracks (e.g., 60% DSA, 30% Backend, 10% AI) to prevent subject neglect.
  - **On-Time Finish Probability**: Statistical confidence score of beating the target deadline.
- **Key Data Generated**: Aggregated metrics over 7-day, 30-day, and all-time windows.

---

### Pillar 7: Local-First Engine & Theme System
- **Capabilities**:
  - **100% Offline SQLite**: WAL mode database with sub-millisecond local reads/writes.
  - **On-Device AI Model Manager**: Downloadable Compact (0.5B) and Balanced (1.5B) GGUF LLMs with pause/resume and zero cloud leakage.
  - **Auto-Backup & Recovery**: Exports unencrypted or encrypted JSON/SQLite snapshots to custom user storage.
  - **Liquid Glass Theme Engine**: 4 ambient palettes (Aurora, Cobalt, Solar, Studio) and 5 dynamic subject signature auras.
  - **In-App Updater**: GitHub-based release checker and native package installer.

---

## 3. Modular Component Lego Blocks

As a designer, you can freely move, merge, or re-imagine these building blocks across any screen in your new layout.

### Block A: The Rhythm Pill HUD (Velocity & ETA Telemetry)
* **What it does**: The central GPS speedometer for the learner's curriculum.
* **Data displayed**:
  - Status Badge: `ON TRACK` (emerald), `PACE ADAPTED` (amber), `OPEN PACE` (cyan).
  - Target Deadline vs. Predicted Completion Date.
  - Required Daily Minutes (e.g., `45m / day`) vs. Current 7-Day Velocity.
  - Remaining days countdown.
* **Interactive Controls**:
  - Tap to expand/collapse full telemetry.
  - Quick action buttons: `Adjust Deadline`, `Split Heavy Tasks`, `Study Ahead`.
* **Design Opportunities**:
  - Can be a floating header capsule, a sticky bottom bar, an Apple Watch-style ring widget, or integrated into the top bar.

---

### Block B: 7-Day Streak & Activity Matrix
* **What it does**: Tracks daily study consistency and momentum.
* **Data displayed**:
  - Days of the week (`M`, `T`, `W`, `T`, `F`, `S`, `S`).
  - Active study indicator: Glow disc on days with completed beats.
  - Active study streak counter (`🔥 N days active`).
  - Active week label (`Jan 12 - Jan 18`) with `TODAY` reset button.
* **Interactive Controls**:
  - Horizontal swipe gesture to page through past weeks.
  - Tap date to view that day's completed lessons.
* **Design Opportunities**:
  - Can be a full-width header banner, a compact circular progress wheel, or an expandable calendar sheet.

---

### Block C: Spaced Repetition Revision Board
* **What it does**: Prompts quick 5-minute active recall for completed material.
* **Data displayed**:
  - List of topics due today for review.
  - Graduation interval tag (`Day 3`, `Day 7`, `Day 30`).
  - Topic title, track origin, and duration.
* **Interactive Controls**:
  - `Mark Revised` (one-tap checkmark).
  - `Reschedule` (postpone review).
  - `Unshelf` (remove from spaced repetition).
* **Design Opportunities**:
  - Can live on the Home screen, as a dedicated "Flash Shelf" tab, as swipeable Tinder-style flash cards, or in a slide-out drawer.

---

### Block D: Track Todo & Curriculum Card
* **What it does**: Displays the curriculum tree (Chapters & Lessons) for an active track.
* **Data displayed**:
  - Track Title & Subject Category badge (e.g., "PYTHON BACKEND").
  - Subject Accent Dot & Luminous Border (Emerald, Cyan, Violet, Coral, Amber).
  - Overall progress ratio (`14 of 48 beats`, `29%`).
  - Glowing Liquid Progress Bar.
  - Chapter Accordions: Chapter title, lesson count, total duration.
  - Lesson Row (Beat): Checkbox, Beat Title, Part badge (`Part 1/2`), Duration (`18m`), Notes badge, Video icon.
* **Interactive Controls**:
  - Tap checkbox: Mark complete.
  - Tap lesson body: Open Focus Mode (`SessionDetailScreen`).
  - Long press / 3-dot menu: Split task, Mark confusing, Delay, Add custom note.
* **Design Opportunities**:
  - Can be card-based, kanban column-based, tree node-based, or timeline stream-based.

---

### Block E: Focus Session Workspace (`SessionDetailScreen`)
* **What it does**: The distraction-free study environment where the user actually learns.
* **Data displayed**:
  - Track title & Chapter breadcrumb.
  - Current Beat title and duration.
  - Video player or direct resource link.
  - Study timer (countdown or stopwatch).
  - Notes & key takeaways field.
* **Interactive Controls**:
  - Complete lesson button.
  - Previous / Next lesson stepper.
  - Split task button.
  - Mark confusing button.
* **Design Opportunities**:
  - Can be a full-screen immersive view, a split-screen iPad layout with video on top and notes on bottom, or a picture-in-picture player.

---

### Block F: Liquid Glass Date & Deadline Picker (`GlassDatePickerSheet`)
* **What it does**: Allows selecting track start dates and target deadlines.
* **Data displayed**:
  - Month & Year selector with frosted arrow navigation.
  - Quick presets: `Today`, `+1 Week`, `+2 Weeks`, `+1 Month`, `+3 Months`.
  - 7-column calendar grid with glowing selected date pill.
* **Design Opportunities**:
  - Replaces all stock Android/iOS date pickers. Can be rendered as a bottom sheet, an inline wheel, or a full calendar dialog.

---

### Block G: Ingestion & Playlist Importer Modal (`NewTrackModal`)
* **What it does**: Ingests external curricula into structured tracks.
* **Data displayed**:
  - Mode Tabs: `YouTube Playlist`, `Syllabus / Markdown`, `Manual Blueprint`.
  - Input field: URL or text input.
  - Real-time video preview: Title, estimated total hours, video count, thumbnail.
  - Deadline input trigger (`Select Target Date`).
  - Pacing estimation banner: *"Will require ~35 mins/day to finish by [Date]"*.
* **Interactive Controls**:
  - Paste clipboard button.
  - "Start Learning Track" CTA button.

---

### Block H: Velocity & Balance Analytics Cards
* **What it does**: Visualizes study habits and trajectory.
* **Data displayed**:
  - Metric 1: Total Study Hours.
  - Metric 2: Weekly Velocity Index (beats/week).
  - Metric 3: On-Time Probability (percentage).
  - Chart 1: Daily Study Intensity (Bar chart Mon–Sun).
  - Chart 2: Subject Share (Donut / Radial chart of tracks).
* **Design Opportunities**:
  - Can be its own dedicated tab, a swipeable header card on Home, or an end-of-week review modal.

---

### Block I: Settings, AI & Theme Controls
* **What it does**: Power-user configuration, local models, and themes.
* **Data displayed**:
  - Appearance Mode: `System`, `Dark`, `Light`.
  - Liquid Glass Theme: `Aurora`, `Cobalt`, `Solar`, `Studio` (with dual-gradient color preview dots).
  - Weekly Study Intensity: 7 day sliders (minutes per day).
  - Local AI Engine: Model download progress (`Compact 0.5B` vs `Balanced 1.5B`), model storage footprint, cancel/pause buttons.
  - Auto-Backup: Backup directory selector, frequency dropdown (`Daily`, `Weekly`), `Export Backup`, `Restore Backup`.
  - App Updater: Version badge, `Check for Updates`, change notes.

---

## 4. Current Screen Layout vs. Redesign Ideas

### Current 4-Tab Architecture
```
┌────────────────────────────────────────────────────────┐
│                      TOP BAR                           │
│  RYTHEM              [Sync] [Tracks (2)] [Settings]    │
├────────────────────────────────────────────────────────┤
│                      TAB BODY                          │
│                                                        │
│  Tab 1: FLOW (Streak + Rhythm Pill + Revision + Todos) │
│  Tab 2: EXPLORE (All Tracks + New Track + Detail)      │
│  Tab 3: METRICS (Charts + KPIs + Balance)              │
│  Tab 4: SETTINGS (Themes + AI + Backups + Intensity)   │
│                                                        │
├────────────────────────────────────────────────────────┤
│           FLOATING GLASS BOTTOM DOCK (4 Items)         │
│         [Flow]      [Explore]    [Metrics]  [Settings] │
└────────────────────────────────────────────────────────┘
```

---

### 3 Innovative Layout Ideas for the Designer to Explore

#### 💡 Idea 1: The "Unified Command Center" (3-Tab Streamlined)
- **Tab 1: Today / Flow**: Combines Streak, the Rhythm Pill HUD, Today's Queue, and Spaced Revision. Merges velocity mini-KPIs directly into an expandable top card so users rarely need to leave Tab 1.
- **Tab 2: Library / Tracks**: All curricula, chapter accordions, ingestion wizard, and syllabus gap inspection in one unified space.
- **Tab 3: Studio / Engine**: Personal analytics, 7-day study intensity scheduler, themes, on-device AI models, and backups.

#### 💡 Idea 2: The "Spatial Linear" Layout (Feed + Drawer)
- **Primary Feed**: A continuous timeline showing:
  1. *Morning*: Spaced Revision shelf (5 mins).
  2. *Afternoon/Evening*: Today's target beats.
  3. *Footer*: Real-time GPS velocity and streak progress.
- **Side Slide-Over / Sheet**: Pull up from bottom or slide from left to access the full track library, roadmap trees, and settings.

#### 💡 Idea 3: "Card-Deck Focus" (Mobile First)
- Instead of long vertical lists, present Today's Focus as a **stacked deck of frosted glass cards**:
  - Card 1: Daily Spaced Revision item.
  - Card 2: Current high-priority lecture.
  - Card 3: Next sequential lesson.
- Swipe card right = Complete. Swipe card left = Delay / Split. Tap = Focus Session.

---

## 5. UI States & Edge Cases (Crucial for Figma Screens)

For each screen you design, make sure to generate these states:

| State | Visual Treatment / Behavior |
| :--- | :--- |
| **Empty State (Day 0)** | No tracks enrolled yet. Frosted glass illustration, inspiring quote, and prominent "Import YouTube Playlist or Syllabus" button. |
| **Active / On Track State** | Emerald glowing badges, steady velocity metrics, glowing calendar streak flame. |
| **Pace Adapted (Missed Days)** | Solar Amber soft glow on Rhythm Pill. Displays friendly recalculation: *"3 days missed. Added 6 mins/day to remain on track."* Zero red alerts. |
| **All Goals Completed State** | Celebration glass card: *"Today's Flow Complete"*, evening unlock badge flips, next study recommendation for tomorrow. |
| **Curriculum Completed State** | Gold / holographic celebration badge: *"100% Curriculum Mastered"*, prompts export certificate / backup archive. |
| **Downloading Local AI State** | Glass progress indicator with download percentage, downloaded MB / total MB, pause and cancel buttons. |
| **Offline Mode State** | Subtle offline badge; all features continue working 100% locally from SQLite. |

---

## 6. Color Tokens & Subject Accent Palette

Rythem uses a curated palette where color communicates meaning and topic personality:

### Theme Palettes (Ambient Aurora Lighting)
- **🌌 Liquid Aurora** *(Default)*: Electric Cyan (`#00E5FF`), Cosmic Violet (`#9D4EDD`), Deep Royal Indigo (`#3A0CA3`).
- **⚡ Cyber Cobalt**: Ice Blue (`#00B4D8`), Bright Azure (`#0096C7`), Deep Cobalt (`#023E8A`).
- **🔥 Solar Ember**: Warm Honey Amber (`#FF9500`), Terracotta (`#9A3412`), Golden Glow (`#D97706`).
- **🎬 Studio Monochrome**: Specular White (`#FFFFFF`), Slate (`#8E8E93`), Obsidian (`#111113`).

### Subject Accent Discs & Progress Bars
- 🟢 **Emerald Mint (`#00E676`)**: Python, Backend Engineering, Systems, Go, Rust.
- 🔵 **Electric Cyan (`#00E5FF`)**: Data Structures, Algorithms, C++, Logic.
- 🟣 **Royal Violet (`#B388FF`)**: Artificial Intelligence, Machine Learning, Mathematics, Data Science.
- 🟠 **Sunset Coral (`#FF6E40`)**: Frontend, Mobile, Flutter, React, UI/UX Design.
- 🟡 **Solar Amber (`#FFD600`)**: System Design, Cloud Architecture, Databases, Distributed Systems.

### Typography (Google Poppins Scale)
- **Display / Brand**: Poppins Bold 20–24, Letter Spacing 1.5–2.0 (Uppercase).
- **Headlines**: Poppins SemiBold 18–22.
- **Section Headers**: Poppins Bold 10–12, Letter Spacing 1.2–1.5 (Uppercase).
- **Card Titles**: Poppins SemiBold 14–16.
- **Body**: Poppins Regular 13–14.
- **Captions & Badges**: Poppins Medium/SemiBold 9–11.

---

## 7. Designer Checklist: Screens to Generate in Figma

To completely redesign Rythem, create these artboards:

- [ ] **1. Onboarding Flow**:
  - Welcome & value proposition (GPS pacing, zero backlog debt).
  - Study style selector (Intensive vs. Balanced vs. Casual).
  - Preferred study days selector (Mon–Sun).
- [ ] **2. Flow Screen (Home)**:
  - Default Active state (Streak calendar, Rhythm Pill HUD, Daily Revision Board, Track Todo cards).
  - Pace Adapted state (Amber recalculation capsule).
  - Empty state (Prompt to add first track).
- [ ] **3. Focus Mode (`SessionDetailScreen`)**:
  - Immersive player with timer, video link, notes, and previous/next stepper.
- [ ] **4. Explore / Library Screen**:
  - Search bar, Track cards with subject accent discs & liquid progress bars.
- [ ] **5. Ingestion Wizard Modal (`NewTrackModal`)**:
  - YouTube playlist URL input, video preview card, duration calculator, deadline picker trigger.
- [ ] **6. Roadmap Detail Screen**:
  - Chapter accordions, lesson rows, inline ambiguous match confirm/reject card, topic adder.
- [ ] **7. Metrics / Analytics Screen**:
  - KPI cards (Velocity, On-Time Probability, Study Hours), 7-day intensity chart, subject share donut.
- [ ] **8. Settings Screen**:
  - Appearance toggle, 4-theme palette switcher with mini gradient dots, 7-day schedule sliders, on-device AI download manager, backup manager.
- [ ] **9. Contextual Sheets**:
  - `GlassDatePickerSheet` (Calendar sheet with quick presets).
  - `GlassActionSheet` (Context menu for lesson/track actions).
  - `TimelineAdjusterSheet` (Slider to glide deadline and preview minutes/day).
  - `SplitTaskSheet` (Divide 2-hour lecture into parts).

---

*This specification represents the complete production functional state of Rythem v1.0.2-pre.*
