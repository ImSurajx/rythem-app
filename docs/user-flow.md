# user-flow.md - simulated walkthroughs

companion to `system-design.md` and `design.md`. this file simulates a real person using the app, screen by screen, button by button - including all three ingestion conditions, the daily habit loop, falling behind, and the weekly check-in. every screen/state referenced below is defined in `design.md`; nothing here introduces a new screen.

---

## flow 1 - first launch (onboarding)

1. app opens directly to **step 1 - welcome**. one line of philosophy text, one button: "continue". taps it.
2. **step 2 - seed your first roadmap**. two choices shown: "import a syllabus file" or "create blank track", plus "skip for now". taps "import a syllabus file", picks a `dsa-syllabus.json` file from device storage. the syllabus topic list loads in the background - no chapters or beats yet, since no resource is attached at this point.
3. **step 3 - model check**. app auto-detects on-device model support and shows one of two lines: "ready" or "not available on this device - fallback mode". no action needed either way, just acknowledges and continues.
4. **step 4 - pacing calibration**. one selector: light / normal / intense. picks "normal". no numbers shown anywhere on this screen.
5. **step 5 - ready**. one button: "enter flow". taps it, lands on the **flow screen** with the dsa roadmap already listed but showing zero beats, since no resource has been attached to it yet.

---

## flow 2 - the daily habit loop (opened most often, ~95% of sessions)

1. opens the app. lands directly on **flow screen** - no onboarding, no loading delay.
2. sees today's date, current streak, and a short checklist: 2-3 beats across active roadmaps.
3. two ways to act on a beat, both valid:
   - **tap the checkbox directly on flow screen** - beat completes immediately, streak/progress updates live, no navigation needed.
   - **tap a beat's row to open "open session"** - lands on **session detail**, sees this chapter's full beat sequence with the current one highlighted, taps "complete & advance" - the app marks it done and highlights the next beat automatically, no need to back out and back in.
4. once all of today's beats are done, the evening unlock indicator on flow screen flips from locked to unlocked.
5. closes the app. no further action needed until tomorrow.

---

## flow 3 - condition 1: blank track + full playlist attached

*scenario: creating a brand new subject with no existing syllabus, e.g. "rust systems programming".*

1. taps **explore** in the dock. sees existing roadmap cards (dsa, tech-stack, maths).
2. taps **"+ new track"**. **new track modal** opens: fills track title ("rust systems programming"), category ("systems"), pastes a youtube playlist url. taps "create".
3. **processing state** appears: "reading playlist". this is condition 1 - no syllabus exists for this track, so there's nothing to match against, only to organize.
4. ai resource layer clusters the playlist's videos into chapters using title structure (numeric prefixes, keywords). every video becomes a beat - zero videos dropped.
5. **success** - lands on **roadmap detail** for the new track. sees 5-6 auto-clustered chapters, first one expanded, each beat listed in the mentor's original upload order. no `mentor extra` tags appear anywhere in this flow, since there was no baseline syllabus to compare against - that tag only exists in condition 2.

---

## flow 4 - condition 2: existing syllabus + mentor playlist interleaved

*scenario: the dsa track already has a syllabus (topics like arrays, hashing, graphs, etc., imported in flow 1). now attaching the actual video course.*

1. taps **explore**, taps the **dsa** card. lands on **roadmap detail**. progress bar is empty, syllabus topics are listed but no chapters/beats exist yet.
2. taps **"attach resource"**. pastes the code & debug dsa playlist url.
3. **processing state**: "matching to your syllabus". this time a syllabus already exists, so this is condition 2.
4. the ai resource layer walks the playlist in its original chronological order and compares each video against the syllabus topic list:
   - a video on "hash maps and sets" matches the syllabus's existing "hashing" topic - linked automatically, high confidence.
   - a video on "bit manipulation" doesn't exist anywhere in the imported syllabus at all - it's kept in its exact position in the timeline and tagged `mentor extra`, never dropped, never moved to a separate section.
   - a video titled ambiguously (e.g. ties to a topic only loosely by wording) comes back as a **low-confidence match** rather than being silently accepted.
5. **success** - back on **roadmap detail**. chapters now show a mix of plain matched beats, a few `mentor extra` tagged beats, and one beat with an inline prompt: "looks related to sliding window - confirm?" with confirm/reject controls right there. taps confirm on the correct one, taps reject on a wrong suggestion (which simply leaves that beat unmatched, still fully usable, just not counted against a specific syllabus topic).
6. the mentor's chronological order was never altered anywhere in this process - the sequence on screen is exactly the sequence the instructor taught it in.

---

## flow 5 - condition 3: single long crash-course video

*scenario: attaching a single 4-hour "full linear algebra course" video instead of a playlist.*

1. from **roadmap detail** for the maths track, taps **"attach resource"**, pastes a single video url (no `list=` parameter).
2. app detects this is a single video, not a playlist - routes to condition 3 instead of condition 1/2.
3. **sub-case a - the video has description timestamps**: processing state parses them directly (pure pattern matching, no model needed for this part). each timestamp becomes its own beat with an exact deep-link jump. **success** - roadmap detail shows one chapter with 10-15 beats, each linked to its exact second offset in the video.
4. **sub-case b - no timestamps exist at all**: processing falls back to checking for captions/transcript to suggest natural breakpoints. if that's also unavailable, the video becomes a single beat for now, with a manual "split this into parts" action left for later - **success** is still reached, just with less granularity, never a failure state purely because timestamps were missing.

---

## flow 6 - falling behind (the intelligent system)

1. several days pass with beats left unchecked on the tech-stack roadmap specifically.
2. the pacing engine's trend check (running silently in the background of every flow-screen load) detects a sustained shortfall - not just one off day, which would've been absorbed without any interruption.
3. next time the app opens, **flow screen** shows a clear prompt instead of the usual quiet checklist: "tech-stack has fallen behind pace." tapping it opens the **backlog decision screen**.
4. sees four option cards, all equally valid:
   - "push the target date" - shown with what the new realistic date would be
   - "trim to must-do beats only" - drops lower-priority beats from the remaining queue
   - "borrow pace from another roadmap" - shown only if another active roadmap currently has slack
   - "accept and continue" - dismisses cleanly, no penalty, re-checked again after the next stretch
5. picks one. the pacing engine recalculates immediately based on that choice, and flow screen returns to its normal quiet state.

---

## flow 7 - weekly check-in

1. taps **metrics** in the dock.
2. sees lifetime beats completed, a 7-day bar chart with today highlighted, current streak, and velocity.
3. below that, a per-roadmap breakdown list - dsa, tech-stack, maths, each with its own ratio and progress bar.
4. taps the tech-stack row - jumps straight into that roadmap's **roadmap detail**, same screen as flows 3/4/5 would land on, fully consistent no matter which path got there.

---

## flow 8 - settings (rarely visited)

1. taps **settings** in the dock.
2. sees appearance toggle (dark/light - both monochrome), model engine status (on-device / fallback mode, matching whatever was detected during onboarding), the same three-option pacing calibration from onboarding (editable anytime), a "re-run onboarding" action, and version info.
3. changes pacing from "normal" to "intense" - this immediately changes future daily effort-budget calculations without needing to touch anything else.

---

## what stays constant across every flow above

- the bottom dock (flow / explore / metrics / settings) is always the anchor point - every flow above eventually returns to it.
- no screen in any flow shows a raw number of minutes, hours, or a clock.
- the ai resource layer only ever runs inside a processing state, triggered only by attaching a resource - never silently, never in the background during normal daily use.
- every beat, in every condition, ends up checkable from either flow screen directly or session detail - there is no fourth way to mark something done and no beat that's only completable from a special screen.
