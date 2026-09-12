# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-12

### Added
- Clean project initialization with official Flutter SDK toolchain.
- Core local dependencies: `sqflite` (local on-device DBMS), `path_provider`, `google_fonts`, `youtube_explode_dart`.
- Native Android configuration targeting modern SDKs with `INTERNET` and `ACCESS_NETWORK_STATE` permissions.
- Automated GitHub Actions CI pipeline building and releasing `rythem.apk`.
- Monochrome liquid glass design system tokens (pure pitch black `#000000`, translucent glass whites, hairline borders).
- Reusable liquid glass component library (`GlassContainer`, `GlassCard`, `GlassButton`, `GlassProgressBar`).
- Fluid typography system powered by Google Fonts Poppins with rhythmic hierarchy and beat-oriented semantics.
- Tactile micro-interactions (press-scale dynamics, smooth specular highlights, and system haptics).
- Interactive design system showcase demonstrating beat progression, cards, and liquid buttons.
- Apple Control Center style light frosted glass theme on soft ambient platinum canvas with diffuse depth and specular highlights.
- Interactive Dark/Light glass theme switcher toggle with tactile haptic feedback.
- Official 3D metallic liquid glass pulse logo and native Android adaptive launcher icons across all screen densities.
- On-device embedded SQLite database engine (`DatabaseService`) with Write-Ahead Logging (WAL) and foreign key cascades.
- Normalized relational schema contracts (`roadmaps`, `chapters`, `beats`, `beat_logs`, `app_settings`).
- Type-safe immutable domain entity models (`RoadmapEntity`, `ChapterEntity`, `BeatEntity`, `BeatLogEntity`, `AppSettingsEntity`).
- Reactive data repositories (`RoadmapRepository`, `ChapterRepository`, `BeatRepository`, `BeatLogRepository`) with instantaneous `DatabaseEventBus` change stream.
- Unit and integration test suite verifying mentor chronological order, effort weighting, cascading deletes, and streak analytics.
