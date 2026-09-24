# Implementation Plan: Feature 4 — Intelligent Pace Coach & Flexible Timeline Adjuster (No Backlog Debt)

## Problem Statement & User Requirements
As articulated by the user:
> *"now backlog system become useless what do you think but revision is still good"*
> *"the video timestamp & length does that thing make sense to you? by any chance or the hourly weekly calendar?"*

The existing backlog system exposed stressful "debt points" and artificial lag warnings that induced guilt when users had busy schedules. Furthermore, the rigid 7-day hourly matrix tried to enforce fixed daily hours instead of letting users study at their own natural rhythm.

### Guiding Principles & Invariants
1. **Guilt-Free Navigation, Zero Backlog Debt**:
   - Eliminate "shortfall debt" points, punitive warning language, and forced task injections.
   - Pacing is an **informative navigational coach**, like a GPS estimating arrival time.
2. **Real-Velocity Projection**:
   - Calculates projected completion date based on user's actual velocity (completed lessons/parts per active study day).
   - If velocity is steady, projects completion date with mathematical precision:
     $$\text{Projected Finish Date} = \text{Today} + \left\lceil \frac{\text{Remaining Effort}}{\text{Velocity}} \right\rceil \text{ days}$$
3. **Clear, Helpful Status**:
   - 🟢 **On Track**: Projected completion on or before target date.
   - 🟡 **Behind Schedule**: Projected completion after target date (e.g. *"4 days behind target"*).
   - ⚪ **Open Pace**: Untimed roadmap with no target deadline.
4. **Non-Intrusive Guideline Readout**:
   - *"To finish by Nov 30, aim for ~1.5 lessons per day."* (Helpful guidance, never forced into today's mission).
5. **Flexible Timeline Adjuster**:
   - 1-tap options to adapt the schedule when life happens:
     - **+7 Days Extension** (1-tap quick adjustment).
     - **+14 Days Extension**.
     - **Custom Calendar Date Picker**.
     - **Open Pace Mode** (clears target date for stress-free self-paced learning).

---

## Architecture & Proposed Changes

### 1. Domain Models & Pacing Engine

#### A. `PaceStatus` & `PaceHealth` (`lib/core/pacing/models/pacing_budget.dart`)
- Define `enum PaceStatus { onTrack, behindSchedule, openPace }`.
- Add fields to `PacingBudget`:
  - `final PaceStatus paceStatus;`
  - `final DateTime? projectedCompletionDate;`
  - `final int daysAheadOrBehind;` // negative = days ahead, positive = days behind
  - `final double dailyEffortGuideline;` // e.g. 1.5 lessons/day to hit target
  - `final String guidelineMessage;` // e.g. "Aim for ~1.5 lessons/day to finish by Nov 30"
- Maintain existing fields (`isSustainedLag`, `shortfallDebt`, etc.) for complete backwards compatibility with existing test suites.

#### B. `PacingCalculator` (`lib/core/pacing/services/pacing_calculator.dart`)
- Add method `calculatePaceHealth(...)`:
  - Computes user velocity from recent activity (completed lessons or parts per active day).
  - Defaults to sensible fallback (e.g. 1.0 or remainingEffort / daysLeft) if brand new track.
  - Computes `projectedCompletionDate`, `daysAheadOrBehind`, `dailyEffortGuideline`, and `PaceStatus`.
  - Generates clear, motivating guideline text.

#### C. `PacingService` (`lib/core/pacing/services/pacing_service.dart`)
- Integrate `PacingCalculator.calculatePaceHealth` into `computeBudgetForRoadmap`.
- Add method `updateRoadmapTargetDate(String roadmapId, DateTime? newTargetDate)`.

---

### 2. UI Components & Glassmorphism

#### A. `PaceCoachCard` (`lib/features/flow/widgets/pace_coach_card.dart`)
- Replaces the stressful `_SustainedLagRecalibrationBanner`.
- Elegant liquid frosted glass card in `FlowScreen`:
  - **Header**: Compass icon with "Pace Coach" and status badge:
    - 🟢 "On Track" (with specular emerald glow)
    - 🟡 "Behind by X days" (with warm amber glow)
    - ⚪ "Open Pace" (with soft lavender glow)
  - **Metrics Row**:
    - Projected Finish Date (e.g. `Nov 26`)
    - Target Deadline (e.g. `Nov 30`)
    - Current Velocity (e.g. `1.8 lessons/active day`)
  - **Guideline Text**:
    - *"To finish by Nov 30, aim for ~1.5 lessons per day."*
  - **Action Row** (when behind or when tapped):
    - 1-tap **"+7 Days"** quick extension button.
    - **"Adjust Timeline"** button (opens `TimelineAdjusterSheet`).

#### B. `TimelineAdjusterSheet` (`lib/features/flow/widgets/timeline_adjuster_sheet.dart`)
- Frosted liquid glass bottom sheet modal:
  - Current timeline overview: Target Date vs Projected Finish.
  - Quick adjustment pills:
    - **+7 Days Extension**
    - **+14 Days Extension**
    - **+30 Days Extension**
  - **Pick Date on Calendar**: native smooth date picker.
  - **Switch to Open Pace**: removes deadline for self-paced study.
  - Save button with haptic feedback and confirmation glass toast.

#### C. Integration in `FlowScreen` & `RoadmapDetailScreen`
- In `FlowScreen`: display `PaceCoachCard` above the track filter / tasks.
- In `RoadmapDetailScreen`: display pace health chip in the header with 1-tap timeline extension.
- In `main.dart`: wire `onUpdateTargetDate` callback with database reload and toast.

---

## Mathematical Formulation

1. **Velocity Calculation**:
   $$\bar{v} = \frac{\sum_{d \in D_{\text{active}}} \text{effort}_d}{|D_{\text{active}}|}$$
   Where $D_{\text{active}}$ is the set of days on which user completed at least 1 topic or part in the past 14 days. If $|D_{\text{active}}| = 0$, fallback velocity $\bar{v} = \max\left(1.0, \frac{\text{Remaining Effort}}{\text{Days Left}}\right)$.

2. **Projected Days to Completion**:
   $$\Delta_{\text{projected}} = \left\lceil \frac{\text{Remaining Effort}}{\max(0.1, \bar{v})} \right\rceil$$
   $$\text{Date}_{\text{projected}} = \text{Today} + \Delta_{\text{projected}}$$

3. **Days Ahead / Behind**:
   $$\delta = \text{Date}_{\text{projected}} - \text{Date}_{\text{target}}$$
   - $\delta \le 0 \implies \text{PaceStatus.onTrack}$ ($\lvert\delta\rvert$ days ahead)
   - $\delta > 0 \implies \text{PaceStatus.behindSchedule}$ ($\delta$ days behind)
   - $\text{Date}_{\text{target}} = \text{null} \implies \text{PaceStatus.openPace}$

4. **Daily Guideline**:
   $$\text{Guideline} = \frac{\text{Remaining Effort}}{\max(1, \text{Days Left})}$$

---

## Verification Plan

### Automated Test Suite: `test/pace_coach_test.dart`
1. **Mathematical Projection Tests**:
   - Remaining effort = 10, velocity = 2.0/day $\implies$ projected days = 5.
   - Target date in 7 days $\implies$ On Track (2 days ahead).
   - Target date in 3 days $\implies$ Behind Schedule (2 days behind).
   - Target date is null $\implies$ Open Pace.
2. **Multi-Part Scaling in Velocity & Remaining Effort**:
   - Beats split into parts contribute accurately to velocity and remaining effort.
3. **Timeline Extension & Database Persistence**:
   - 1-tap +7 days updates `target_completion_date` in SQLite and recalculates status from behind to on track.
   - Setting target date to null switches status to `openPace`.
4. **Zero Forced Task Injections**:
   - Verify that being behind schedule NEVER auto-injects tasks or alters Today's Focus.

### Full Regression Suite
- Run `flutter analyze` (0 errors/warnings).
- Run `flutter test -j 1` across all test suites.
