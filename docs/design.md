# design.md - screen-by-screen page design

companion to `system-design.md`. this file only covers what's *on* each page and what's deliberately kept off it. one primary purpose per screen - if a screen needs a "not contains" line, that line is doing real work, not filler.

visual theme (unchanged, not repeated per screen below): monochrome black & white liquid glass, no color anywhere except external video thumbnails/avatars. no numbers, minutes, or clocks visible anywhere in the app - progress is always shown as beats and progress bars, never time.

---

## 0. onboarding / setup wizard (first launch only, 5 steps)

### step 1 - welcome
- contains: one-line philosophy statement (beats over clocks), single "continue" action
- not contains: any settings, any input field

### step 2 - seed your first roadmap
- contains: two choices only - "import a syllabus file" or "create blank track" - plus a "skip for now" option
- not contains: resource attachment (that happens later, per-roadmap, in roadmap detail)

### step 3 - model check
- contains: automatic on-device model detection result ("ready" or "not available on this device - fallback mode", with a note that an offline model can be downloaded in settings anytime), no user action needed beyond acknowledging
- not contains: an api key field - this app doesn't ask for one

### step 4 - pacing calibration
- contains: one selector with three plain options (light / normal / intense), nothing numeric shown
- not contains: any mention of minutes, hours, or a raw beats-per-day count

### step 5 - ready
- contains: single confirmation, one "enter flow" action
- not contains: anything else

---

## 1. bottom dock (persistent across the 4 main screens)

- contains: four icons only - flow, explore, metrics, settings - each with a short label, one visibly selected
- not contains: badges, notification counts, a fifth item

---

## 2. flow screen (home - the screen opened most often)

- contains: today's date, streak indicator, today's beat checklist (one row per pending beat across active roadmaps, each directly checkable), an evening unlock indicator, a single "flag something confusing" action
- not contains: charts, settings, any single roadmap's full detail, anything requiring more than a glance to parse

---

## 3. session detail (focus mode, opened from flow)

- contains: current roadmap + chapter label only, a vertical sequence of this chapter's beats, one "complete & advance" action that always does the obvious next thing
- not contains: the bottom dock (hidden while focusing), any other roadmap, settings access

---

## 4. explore screen (all roadmaps)

- contains: a search field, one card per roadmap (title, category, a progress bar, a beat-ratio like "7 of 21"), a single "+ new track" action
- not contains: expanded chapter/beat lists (that's roadmap detail), any settings

---

## 5. new track modal

- contains: track title field, category field, an optional resource url field (accepts youtube playlist/video or documentation/article links), one "create" action
- not contains: model or pacing configuration - those are already set globally, not repeated per track

---

## 6. roadmap detail (one subject, full depth)

- contains: title/category header, overall progress bar, an "attach resource" action (accepts youtube or documentation links; auto-synthesizes chapters even if syllabus is broad like "Precalculus"), chapter accordion (first chapter open by default), and within each chapter: beats with a checkbox, a `mentor extra` tag where relevant, and an inline confirm/reject control on any low-confidence syllabus match
- not contains: any other roadmap, a full ai chat interface, raw duration/time figures

---

## 7. processing state (shown only while a resource is being attached)

- contains: one plain status line ("reading playlist" / "matching to your syllabus"), and on completion either a return to roadmap detail with results populated, or a clear failure message with a retry action and a "continue without matching" fallback
- not contains: technical logs, a percentage progress bar, any output from the model shown raw

---

## 8. metrics screen

- contains: lifetime beats completed, a 7-day activity bar chart with today highlighted, streak, velocity, and a per-roadmap breakdown list (tapping a row opens that roadmap's detail)
- not contains: any editing action, settings, time-based figures

---

## 9. settings screen

- contains: appearance toggle, model engine status (on-device / fallback mode) with an option to download an offline model (choice between compact ~400MB or balanced ~1.5GB) when in fallback mode, pacing calibration (same three-option selector as onboarding, editable anytime), a "re-run onboarding" action, version info
- not contains: an analytics dashboard, an ai chat surface, anything requiring more than one tap to reach

---

## 10. backlog decision screen (shown only when the trend check trips)

- contains: a one-line explanation of which roadmap fell behind and by how much (in beats, not time), and exactly four option cards - push the target date, trim to must-do beats only, borrow pace from a roadmap that's ahead, or accept and continue
- not contains: a forced action beyond picking one card - "accept and continue" is always a complete, valid, guilt-free choice

---

## design rule for anything not listed above

if a new idea doesn't obviously belong on one of the ten pages above, it does not get a new page by default - it either fits inside an existing "contains" line or it waits. this list is the ceiling, not a starting point to build up from.
