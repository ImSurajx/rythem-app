# system-design.md - rythem

this is the architectural layer, agreed before any data schema or screen-by-screen build spec. everything below this point (data model, ai service spec, pacing engine spec, individual screens) must conform to what's decided here. this document is intentionally the *shape* of the system, not the implementation detail - that comes next, one part at a time.

---

## 1. philosophy (unchanged from earlier decisions, restated as ground truth)

- **zero time-counting.** no stopwatches, no minute/hour tracking visible anywhere in the ui. progress is measured in discrete **beats** completed, never clock time.
- **mentor's flow is king.** when a resource (playlist/video) is attached, the creator's actual teaching order is ground truth. nothing gets reordered to match a textbook syllabus - extra topics the syllabus doesn't have are kept exactly where the mentor taught them, tagged, never dropped or moved to a bin.
- **math decides, ai narrates, notifications remind.** three distinct jobs, never blurred:
  - the pacing engine (pure math) computes and adapts every number.
  - the ai model explains those numbers in readable language, and does the one-time ingestion work (chaptering, syllabus matching). it never decides a target and never invents pacing logic.
  - notifications are plain, local, math-derived strings ("3 beats pending today") - never ai-generated at fire time, since a notification must be instant and can't depend on a model call succeeding.
- **visual theme is locked**: monochrome black & white liquid glass. no color anywhere in the ui except external video thumbnails/creator avatars. this doesn't change in this document or after.
- **naming**: the atomic unit of work is called a **beat**, not a checkpoint. reinforces the app's own name and the "felt, not measured" philosophy.

---

## 2. the two-engine architecture

everything in the app is either the ai layer or the math layer. nothing else exists as a third kind of intelligence.

```
external source (youtube playlist / video)
        |
        v
  AI RESOURCE LAYER  <-- runs once, only when a resource is attached
        |
        v
   local storage  <-- roadmap -> chapter -> beat, persisted on-device
        |
        v
  PACING ENGINE  <-- runs constantly, every app open, every beat toggle
        |
        v
   ui screens (flow / explore / metrics / settings)
```

**why this separation is load-bearing, not stylistic:**
- the ai layer is the only piece of the system that is occasionally slow, occasionally network- or model-dependent, and occasionally fallible. it is deliberately boxed into one moment (resource attachment) so its cost and risk never touch daily use.
- the pacing engine is the only piece that must be instant and 100% reliable every single time the app opens. it has zero dependency on the ai layer having ever succeeded perfectly - it works off whatever is in storage, however it got there.
- this means a bad or partial ai result (a video misclustered, a mismatch) degrades gracefully - the beat still exists, still counts, still gets scheduled. it just might carry a wrong tag until corrected. it can never break the app's core daily loop.

**the reactive loop**: any beat toggled complete, on any screen, writes to local storage and fires a change notification. every open screen (flow, explore, metrics) re-renders from that single source of truth immediately - no reload, no re-fetch, no ai call involved.

---

## 3. the ai resource layer (ingestion - the most important part to get right)

this runs exactly once per resource attachment event. it is never in the daily critical path.

### 3.1 what it's given
- a youtube playlist or video url
- (optional) an existing syllabus outline already attached to the target roadmap, if one exists

### 3.2 what it must produce
a `Chapter -> Beat` structure for the roadmap, where every beat carries:
- a title
- a link back to the source video and, where available, an exact timestamp offset
- a flag: is this a syllabus match, or a mentor-taught extra not in the baseline syllabus
- if matched, which syllabus topic it satisfies

### 3.3 the three ingestion conditions

**condition 1 - blank roadmap + playlist attached (no syllabus yet)**
- every video in the playlist becomes a beat. zero videos may be dropped or skipped - 100% coverage is a hard requirement.
- videos are clustered into chapters using title structure (numeric prefixes, topic keywords). typical output is 4-8 chapters, not one flat list of 40+ beats.
- no syllabus exists yet, so nothing is tagged as mentor-extra - this condition is pure organization, not alignment.

**condition 2 - existing syllabus + mentor video/playlist attached**
- the mentor's chronological order is preserved exactly, start to finish. this is never reordered to match the syllabus's own structure.
- each video/chapter is compared against the syllabus's topic list. a match links the beat to that syllabus topic.
- anything the mentor covers that isn't in the syllabus is kept in its exact position in the timeline and tagged `mentor_extra: true` - never deleted, never moved to a separate section.
- **sub-case: broad or coarse syllabus (e.g. track just named "Precalculus" with no fine-grained outline)**:
  - if the syllabus contains only a high-level subject name or broad headings, the engine treats the playlist as the primary narrative spine.
  - it clusters the playlist into chapters and beats, associating the full curriculum under the broad subject header without demanding a micro-syllabus or failing.
- **this matching step is the single highest-risk part of the whole ai layer**, and needs an explicit confidence/confirmation model, not silent trust:
  - a match is either high-confidence (shown as matched, no action needed) or low-confidence/ambiguous (shown to the user as a suggested match they can confirm or correct with one tap before it's treated as ground truth).
  - nothing marks a syllabus topic "satisfied" purely from an unconfirmed low-confidence match - this protects the one thing that would otherwise be silently and invisibly wrong: your actual coverage picture.

**multi-type resource linking (youtube, documentation, articles, local files)**
- while youtube videos and playlists are the primary audio-visual ingestion source, beats are resource-agnostic.
- if a topic has no video available (or for documentation-heavy tracks like language specs or API guides), beats can link directly to external documentation (e.g. MDN, official docs), article URLs, or local text/pdf references.
- when opened, non-video resources launch the appropriate documentation reader or web link, and still participate in the exact same effort budget and pacing engine as video beats.

**condition 3 - single long video (crash course / multi-hour lecture)**
- if the description contains chapter timestamps (`mm:ss`, `hh:mm:ss`, `[mm:ss]` patterns), each one becomes a distinct beat with an exact deep-link (`&t=Ns`). this sub-case is pure regex, deterministic, needs no model at all.
- if no timestamps exist, fall back to captions/transcript if available to suggest natural breakpoints; if nothing is available at all, the video becomes one single beat with manual timestamp-splitting left as a user action later, not blocked on ai.

### 3.4 model choice and fallback
- primary: on-device model (e.g. gemini nano via android's ml kit genai prompt api / aicore) for the matching and clustering steps - genuinely local, no api key, no per-call cost, no network dependency at ingestion time on supported hardware.
- **hardware-gated with user download option**: if a pre-installed native model is not detected, the app operates in fallback mode (heuristic clustering and keyword matching). however, users can opt to download a local model in Settings at any time (offering a compact ~400MB model for low-RAM devices, or a balanced ~1.5GB model for higher fidelity).
- **working around the downloaded model**: when a model is downloaded, the app runs local inference sessions directly on-device (using on-device engine runtimes like GGUF / ONNX / TFLite) to process playlist titles and syllabus topics 100% offline, keeping all intelligence local to the phone without ever pinging a cloud API.
- the youtube scraping itself (`youtube_explode_dart`) is unrelated to model choice and always works the same way regardless of device - no api key needed for that layer either.

### 3.5 the ingestion ui state (previously undefined - now explicit)
attaching a resource is not instantaneous and must show a real, bounded state, not a silent hang:
- **processing**: a visible state while the ai layer runs (clustering/matching), shown on its own, not folded invisibly into the attach button.
- **success**: returns to the roadmap detail screen with chapters and beats populated, mentor-extra tags visible, low-confidence matches flagged for confirmation.
- **failure**: a clear, distinct state (model unavailable, malformed url, network issue if a fallback path needs it) with a retry action and a path to fall back to a blank/manual structure rather than leaving the user stuck.

---

## 4. the pacing engine (math - runs constantly, fully local, always reliable)

### 4.1 effort-weighted beats, not raw counts
every beat carries an invisible effort weight, derived from its actual source video duration at ingestion time. the daily target is never "k beats" as a flat count - it's a **daily effort budget**, and the engine selects however many beats fill that budget from the front of the pending queue, in the mentor's original order. the user never sees a number or a clock - they just see today's beat list. the weighting exists purely so two different days (or two different people) doing "today's beats" are doing roughly comparable real work, without ever surfacing that comparison as a visible time value.

### 4.2 daily target calculation
for each active roadmap:
- `remaining effort` = sum of effort weights across all incomplete beats, in queue order
- `days left` = days until that roadmap's target completion date
- `today's effort share` = remaining effort ÷ days left, recalculated fresh every day - never cached, never carried as a stale number
- the engine walks the pending beat queue in mentor order and selects beats until their combined weight meets today's share, then stops - that selected list is what renders as "today"

### 4.3 backlog handling (redistribution, not stacking)
a day that falls short doesn't get bolted onto the next day as an inflated target. because the formula recomputes `remaining ÷ days left` fresh every day, a missed day's leftover work is automatically spread thin across every remaining day - the pace nudges up slightly everywhere, not violently in one place.

### 4.4 when the intelligent system steps in
a single off day is absorbed silently - no alert, no interruption. a **sustained** pattern (several days in a row falling short) is what triggers a decision moment, and it always presents real options rather than silently escalating a number:
- push the roadmap's target date out to a realistic one
- drop to must-do-tier beats only, where priority tiers exist
- borrow slack from another roadmap that's currently ahead of its own pace
- consciously accept and continue, re-checked again after the next stretch

none of these are auto-applied. the user always picks.

### 4.5 notifications
pending-work notifications are fired directly from the pacing engine's own numbers - "3 beats pending today" style, plain and local, no ai call in the loop at notification time. richer, narrated explanation only happens once the user actually opens the app.

---

## 5. screen navigation (confirmed shape)

```
onboarding (first launch only)
        |
        v
bottom dock: flow | explore | metrics | settings
        |
   +----+----------------------+
   v                           v
flow screen                explore screen
(today's beats)             (all roadmaps)
   |                           |
   v                           v
session detail            new track modal --> roadmap detail
                                                    |
                                          attach resource
                                                    |
                                          processing state (section 3.5)
                                                    |
                                        success / failure --> back to roadmap detail
```

metrics screen reads the same storage as flow/explore (7-day activity, streak, per-roadmap breakdown) and links into roadmap detail from any track row. settings holds theme, model engine status, and pacing calibration only - no logic of its own.

---

## 6. build principle for whoever implements this (antigravity or otherwise)

this document defines boundaries an implementing agent must not cross in a single task:

- the ai resource layer and the pacing engine are separate modules with no shared code path. an agent implementing one must never be asked to also implement the other in the same task.
- the pacing engine must be built and independently testable with zero ai/network dependency before any ingestion work begins - it is the piece the whole app degrades gracefully to if everything else fails.
- the ingestion ui state (processing / success / failure) is its own explicit task, not an assumed side effect of the "attach resource" button.
- no single delegated task should span more than one layer of the diagram in section 2. if a task description mentions both "parse the playlist" and "update the flow screen," it is too large and must be split.

---

## 7. what comes next

this document is architecture only. the following are deliberately not yet defined and are the next parts to build, one at a time, each its own document:

1. full data model (`Roadmap`, `Chapter`, `Beat` schemas, effort weight field, mentor-extra/match-confidence fields)
2. ai resource layer implementation spec (exact prompts/model calls, fallback heuristics in detail)
3. pacing engine implementation spec (exact formulas, trend-check thresholds, decision-option logic)
4. screen-by-screen functional spec (flow, explore, roadmap detail, session detail, metrics, settings, onboarding)
