# Release

## v2.0.0
- **User-Defined Beat & Effort Points Preservation**: Full Markdown and JSON syllabus parsing support for custom beat/effort weights across bracket notations (`[2.5]`, `[effort: 3.0]`, `[2.5 beats]`, `[2 pts]`), parenthetical notations (`(2.5)`, `(3 beats)`), delimiters (`| 2.5 beats`, `- 2.5 beats`, `: 2.5 beats`), and prefix notations.
- **Accurate Roadmap Effort Accounting**: When creating tracks from syllabus files or pasted markdown, user-specified effort points are strictly honored and preserved when no resource is attached, cleanly reflecting total effort in pacing budgets, progress meters, and metrics dashboards.
- **Resource Attachment & Gap Preservation**: When attaching video resources to subjects/chapters, covered videos cleanly adopt duration-based effort weights while uncovered syllabus benchmark gaps preserve their custom user-defined effort weights rather than resetting to default.
- **Enhanced SyllabusTopic Data Architecture**: Upgraded `SyllabusTopic` with native `effortPoints` modeling, safe numeric type-casting, and serialization parity across database entities and ingestion parsers.

## v1.1.9
- **Real Location Weather & Natural Diurnal Greetings**: Integrated GPS-based live ambient weather using Open-Meteo and BigDataCloud free APIs (zero signup, zero API keys) with accurate diurnal time-of-day greetings (e.g. 1 AM is classified as night, reflecting true diurnal and weather conditions).
- **Daily Inspirational Quotes**: Seamless daily quote integration in Flow Screen powered by ZenQuotes and DummyJSON free public endpoints (zero signup, zero keys) with an offline curated mastery reserve.
- **Minimalist Apple-Style Onboarding**: Streamlined first-launch wizard with clean circular raw icon navigation, elegant progress indicators, and removed box shadows for crisp icon rendering.
- **Open Lab Progress Tracking & Pinned Header**: Open Lab card now features a dedicated progress meter and stays pinned to the top of the Explore screen for persistent visibility, with refined icon styling.
- **Flag Notes & Friction Deletion**: Direct deletion on Explore flag note cards, "Remove Flag" action in confusion dialogs, and one-tap reflection clearing in checkpoint dialogs.
- **Global App UI Enhancement**: Overhauled visual aesthetics with electric cyan and amber accent gradients, luminous glowing progress meters, liquid glass cards, and an elevated frosted bottom navigation dock.
- **In-Place Backup Engine Replacement**: Overhauled local backup storage to atomically replace and update the master backup file in place, preventing timestamped file clutter and conforming to global button styling.
- **Global Terminology Shift to "Beats"**: Unified progress tracking and task weights to "Beats" across metrics, flow screens, checkpoint dialogs, custom tasks, roadmaps, and offline AI mentors.
