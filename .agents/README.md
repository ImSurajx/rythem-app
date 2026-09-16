# Rythem Agent Documentation Hub

Welcome to the Rythem agent documentation hub. This directory contains comprehensive technical specifications and onboarding material for AI agents and engineers working on Rythem.

---

## 📚 Documentation Index

1. **[ARCHITECTURE.md](file:///Users/itsurajx/Developer/rythem-app/.agents/ARCHITECTURE.md)**:
   - System identity and core philosophy ("Beats Over Clocks", "Mentor's flow is king").
   - Complete directory structure and folder linking breakdown.
   - Core data pipelines:
     - Real-time beat toggle synchronization pipeline.
     - YouTube playlist and Markdown syllabus ingestion pipeline.
     - Dynamic pacing dilution and mathematical quota engine.
     - Offline private AI mentorship pipeline (Qwen 2.5 SLMs).
   - Key architectural contracts and invariants.

2. **[DEVELOPER_GUIDE.md](file:///Users/itsurajx/Developer/rythem-app/.agents/DEVELOPER_GUIDE.md)**:
   - CLI commands (`flutter analyze`, `flutter test`, `flutter build apk`).
   - Core development patterns (Repositories pattern, State management, In-flight sync).
   - Liquid glass design system and rendering performance rules.
   - Testing and verification checklist.

3. **[rules/rules.md](file:///Users/itsurajx/Developer/rythem-app/.agents/rules/rules.md)**:
   - Step-by-step implementation rules.
   - Mandatory user checkpoints and permission protocol.
   - Git commit sign-off (`git commit -s`) standards.
   - Release and changelog maintenance rules.

---

## 🚀 Quick Orientation

- **Language & Framework**: Dart 3.x / Flutter (Stable Channel).
- **Core Database**: Embedded SQLite (`sqflite`) via `DatabaseService`.
- **Primary Entry Point**: [lib/main.dart](file:///Users/itsurajx/Developer/rythem-app/lib/main.dart).
- **Domain Modules**: Located in [lib/features/](file:///Users/itsurajx/Developer/rythem-app/lib/features/) (`flow`, `explore`, `metrics`, `onboarding`).
- **Core Infrastructure**: Located in [lib/core/](file:///Users/itsurajx/Developer/rythem-app/lib/core/) (`database`, `pacing`, `ai`, `theme`, `widgets`).
