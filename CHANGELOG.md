# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-09-19

### Fixed
- **Sequential Chapter-First Daily Suggestions**: Resolved cross-chapter queue walking bug where beats from disparate chapters with identical sort orders jumped to the front; queue walker now strictly enforces chapter sequence.
- **Stable Daily Mission & Strikethrough Retention**: Fixed premature disappearance of uncompleted tasks upon marking a beat complete; today's mission is now date-locked in SQLite so completed tasks stay visible with strikethroughs all day without erasing pending tasks.
- **Goal-Date-Driven Mathematical Pacing**: Replaced flat schedule overrides with required pace calculation ($\text{remainingEffort} / \max(1, \text{daysLeft})$) modulated by weekly study rhythm multipliers.
- **AI Bottleneck Chapter Alignment**: Preserved chronological chapter sequence during local AI shortfall bottleneck analysis.

## [1.0.0] - 2026-09-16

### Initial Production Release

#### Learning Operating System & Pacing Engine
- **"Beats Over Clocks" Core Philosophy**: Milestone-driven learning framework that eliminates toxic overdue banners and arbitrary timers.
- **Dynamic Pacing Dilution**: Mathematical engine that redistributes remaining effort across user calendar windows when days are missed.
- **Evening Unlock**: Psychological rest confirmation activated upon completing daily mission quotas.
- **Configurable Study Rhythm**: 7-day custom study intensity schedules (Default, Accelerated, Gentle).

#### Curriculum Ingestion & Alignment
- **YouTube Playlist Extraction**: Recursive batch extraction supporting extensive playlists (100+ to 230+ videos) with chunked chapter clustering.
- **Syllabus Outline Parsing**: Markdown syllabus ingestion with semantic matching and "Mentor Extra" alignment indicators.
- **Resource Linking**: Direct one-tap linking of videos, timestamps, and documentation to individual beats or entire chapters.

#### Offline-First Local Intelligence
- **Private On-Device AI Mentorship**: Direct support for Compact Mentor (Qwen 2.5 0.5B) and Balanced Mentor (Qwen 2.5 1.5B) via GGUF local inference.
- **Automatic Background Downloading**: Seamless model selection during onboarding with automatic background downloads and graceful heuristic fallbacks.
- **Pedagogical Concept Explanations**: Instant on-device explanations for confusing beats and shortfall root cause analysis.
- **On-Demand Revision System**: Spaced repetition engine with forgetting curve calculations, active recall prompts, and prerequisite linking.

#### Performance & Fluid Glass Design System
- **60/120 FPS Rendering**: State preservation across tabs with `FadeIndexedStack` and isolated repaint boundaries for frosted glass surfaces.
- **Frosted Liquid Glass Aesthetic**: Ambient glassmorphism with dynamic specular highlights, custom blur shaders, and dark/light theme support.
- **Haptic Tactility**: Selection haptics on checkboxes, accordions, and navigation controls.

#### Data Reliability & Disaster Recovery
- **Embedded SQLite Architecture**: High-performance local database with foreign key cascade protection and transactional integrity.
- **In-Flight Synchronization Protection**: Debounced real-time event pipeline ensuring Flow (Todo) and Explore (Tracker) never drop concurrent task completions.
- **Full Backup & Restore**: Comprehensive export and restoration of all user roadmaps, chapters, beats, daily activity logs, and settings.
- **Clean State**: Production-ready initialization with no hardcoded sample roadmaps or dummy seed records.
