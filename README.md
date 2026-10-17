<div align="center">

# 🎵 Rythem
### The Local-First Learning Operating System & Milestone Pacing Tracker

[![Release](https://img.shields.io/github/v/release/ImSurajx/rythem-app?color=10B981&label=Release&logo=github)](https://github.com/ImSurajx/rythem-app/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm_Noncommercial_1.0.0-blue.svg)](https://polyformproject.org/licenses/noncommercial/1.0.0)
[![Offline First](https://img.shields.io/badge/Offline-100%25%20Local-10B981)](#-technical-architecture)
[![SQLite](https://img.shields.io/badge/Database-SQLite-003B57?logo=sqlite)](https://sqlite.org)

**Beats over clocks. Milestones over stopwatches. Progress felt, not measured.**

[Key Features](#-key-features) •
[App Walkthrough](#-how-to-operate-the-app) •
[Format Syllabus with GPT](#-how-to-format--import-any-syllabus-using-gpt) •
[Architecture](#-technical-architecture) •
[Building Locally](#-building--running-locally) •
[Contributing](#-contributing)

</div>

---

## 🌟 Why Rythem?

Traditional study trackers trap learners in anxiety: toxic countdown timers, overdue warning banners, arbitrary hour quotas, and rigid schedules that collapse the moment life happens.

**Rythem redesigns self-directed learning from first principles:**

- ⏱️ **Zero Stopwatches**: No minute or hour counting anywhere in the UI. Work is measured in atomic **Beats** (lessons, exercises, topics).
- 🌊 **Dynamic Pacing Dilution**: Missed a day or fell behind? Rythem never shames you. It mathematically redistributes remaining beats across your target completion date.
- 🎯 **User-Driven Focus**: No forced daily grind. Pull topics into your focus queue on demand, conquer them in a distraction-free focus view, and unlock evening rest without guilt.
- 🧪 **Open Lab Sandbox**: Need to log ad-hoc tasks, practice sessions, or spontaneous explorations outside rigid curricula? The built-in Open Lab lets you log custom beats effortlessly.
- 🚩 **Friction Flags & Study Checkpoints**: Flag confusing concepts with reflective notes, log partial progress percentages, and revisit roadblocks systematically.
- 🧠 **100% Private On-Device AI**: Powered by local Small Language Models (Qwen 2.5 GGUF) for offline concept breakdown, shortfall remediation, and active recall without sending data to the cloud.
- 💎 **Obsidian Liquid Glass Aesthetics**: Standardized obsidian frosted glass design system engineered for 60/120 FPS fluid rendering.

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **Milestone Pacing Engine** | Pure mathematical pacing that dynamically balances daily beat quotas based on your custom 7-day study rhythm (Rest, Light, Normal, Deep). |
| **User-Driven Focus Mode** | On-demand topic pull queue with sequential "In Focus" flow, live beat counters, and one-tap Complete & Advance navigation. |
| **Open Lab Tracker** | Flexible sandbox environment to track custom study tasks, spontaneous research, and rapid logs without mutating roadmap structures. |
| **Friction & Checkpoint Logging** | Flag confusing beats, attach friction notes, track percentage progress, and delete or resolve flags across any screen. |
| **YouTube Playlist Ingestion** | One-tap extraction of YouTube playlists (from 10 to 230+ videos) with automatic clustering into structured chapters and video timestamps. |
| **Syllabus Outline Ingestion** | Ingest Markdown syllabi, academic curricula, or textbook tables of contents. Automatically aligns mentor resources with topics. |
| **"Mentor's Flow is King"** | Non-syllabus bonus topics covered by creators are preserved in-place with `Mentor Extra` badges—never deleted or tossed into orphaned bins. |
| **Full Month Habit Calendar** | Interactive emerald streak heat map tracking daily completed beats with honest streak calculations and month-by-month pagination. |
| **Stock-Market Velocity Chart** | Financial-style momentum graphs displaying daily velocity fluctuations, peak performance days, and cumulative lifetime curves. |
| **Segregated Backup Storage** | Separate dedicated directories for automated rolling snapshots (`Rythem/Backups/snapshots/`) and user-triggered manual exports (`Rythem/Backups/manual/`). |
| **In-App GitHub Updater** | Clean glass-styled update checker directly verifying GitHub releases with release changelog viewing and download triggers. |
| **Air-Gapped Data Safety** | Embedded SQLite architecture with transactional cascades, foreign-key safety, and full JSON state backup and restore. |

---

## 📱 How to Operate the App

### 1. Onboarding & Self-Paced Setup
Upon launching Rythem:
- **Philosophy & Freedom**: Experience learning without stopwatch pressure, artificial deadlines, or rigid daily quotas.
- **Select Offline AI Tier**: Choose between **Compact Mentor** (Qwen 2.5 0.5B, ~468MB for low RAM) or **Balanced Mentor** (Qwen 2.5 1.5B, ~1.04GB). Rythem downloads weights seamlessly in the background with automatic heuristic fallbacks.

### 2. Creating or Ingesting Learning Tracks
Navigate to the **Explore** tab to create a track:
- **Paste YouTube Playlist**: Enter any public YouTube playlist URL. Rythem extracts video titles and clusters them into 4–8 organized chapters.
- **Import Syllabus Markdown**: Paste your course outline. Rythem parses chapters, topics, and milestones instantly.
- **Resource Linking**: Tap any beat to attach documentation links, video URLs, or custom notes.
- **Flag Friction / Confusing Beats**: Encountered an ambiguous or difficult concept? Tap the flag icon to store inline friction notes and mark topics for deeper review.

### 3. Conquering Your Daily Flow
Navigate to the **Flow** tab:
- **Today's Focus Queue**: Pull the next topic into your active queue when you are ready to study.
- **Focus Session View**: Tap any beat to enter a focused, distraction-free environment displaying the topic sequence, current beat counter, and a bottom floating action bar with **Complete & Advance**.
- **Open Lab Sandbox**: Switch to Open Lab to log ad-hoc tasks, exercises, or side projects with `⚡ Log Task`.
- **Celebratory Rest State**: Finishing all topics for the day transitions your focus card into a celebratory completion state with unlocked pull controls.

### 4. Analyzing Momentum & Velocity
Navigate to the **Metrics** tab:
- **Full Month Calendar**: Review your monthly emerald streak heat tiles. Tap any day to inspect completed beats and navigate through past months.
- **7-Day Beat Rhythm**: Review bar charts showing daily completed beats over the past week.
- **Monthly Stock Chart**: Track peaks and valleys in learning velocity.
- **Lifetime Curve**: Watch your cumulative completed beats climb.

### 5. Settings, Backups & Updates
Navigate to the **Settings** tab:
- **On-Device AI Engine**: Inspect offline models, toggle active tiers, or monitor background downloads.
- **Isolated Backups**: Automated rolling snapshots run in the background (saved to `Rythem/Backups/snapshots/`), while manual user backups are archived in `Rythem/Backups/manual/`.
- **App Updates**: Check for the latest release via the GitHub API, inspect interactive release notes, and install updates with frosted glass controls.

---

## 🤖 How to Format & Import Any Syllabus Using GPT

You can convert any textbook table of contents, university course outline, certification guide, or curriculum into Rythem in seconds using ChatGPT, Claude, or any LLM.

### 📋 The Master Prompt

Copy and paste the following prompt into ChatGPT or Claude, followed by your raw syllabus or course outline:

```markdown
You are an expert curriculum formatter for the Rythem learning app. 
Please convert the following course outline into clean, valid Markdown using this strict structure:

RULES:
1. Each major module or chapter must start with a level-1 heading: `# Chapter Name`
2. Each individual lesson, topic, or milestone must be an unordered list item: `- Topic Title`
3. Optional: Add estimated effort weight in brackets `[Effort: X]` where X is 0.5 (quick review), 1.0 (standard lesson), 2.0 (in-depth lecture), or 3.0 (capstone / challenging exercise). Default is 1.0.
4. Optional: If you have URLs, add them in parentheses: `- Topic Title [Effort: 1.0] (https://...)`
5. Do not include introductory text, conversational pleasantries, or code wrappers—output pure Markdown only.

RAW SYLLABUS:
[PASTE YOUR SYLLABUS, COURSE TOPICS, OR TABLE OF CONTENTS HERE]
```

---

### 💡 Example Output

```markdown
# 1. Mathematical Foundations & Vector Calculus
- Linear Algebra: Vectors, Spaces & Transformations [Effort: 1.0]
- Matrix Multiplication & Eigenvalues [Effort: 1.5]
- Multivariate Derivatives & Gradients [Effort: 1.0]
- The Chain Rule & Vectorized Backpropagation [Effort: 2.0]

# 2. Deep Neural Architectures
- Multilayer Perceptrons & Activation Functions [Effort: 1.0]
- Loss Functions: Cross-Entropy vs MSE [Effort: 1.0]
- Optimization Algorithms: Adam, RMSprop & SGD [Effort: 1.5]
- Batch Normalization & Dropout Regularization [Effort: 1.5]

# 3. Convolutional Networks & Vision
- 2D Convolutions, Kernels & Feature Maps [Effort: 1.0]
- Pooling Layers & Translation Invariance [Effort: 0.5]
- Classic Architectures: ResNet & EfficientNet [Effort: 2.0]

# 4. Sequence Modeling & Attention
- Recurrent Neural Networks & Vanishing Gradients [Effort: 1.5]
- LSTM and GRU Gated Architectures [Effort: 1.5]
- Scaled Dot-Product Attention Mechanisms [Effort: 2.0]
- Multi-Head Attention & The Transformer Architecture [Effort: 3.0]
```

### 📥 Importing into Rythem:
1. Copy the formatted Markdown output.
2. Open Rythem and tap **Explore** -> **Add Track** -> **Import Syllabus Outline**.
3. Enter a Track Title, set your Target Completion Date, paste the Markdown, and tap **Create Learning Track**.

---

## 🏗️ Technical Architecture

Rythem is engineered with clean layered architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                       PRESENTATION LAYER                    │
│   FlowScreen  │  ExploreScreen  │  MetricsScreen  │ Settings│
│    (Obsidian Liquid Glass System · 12px Standardized Glass) │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    IN-FLIGHT SYNC PIPELINE                  │
│       Optimistic Toggle Registry · Debounced DB Reload       │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                        DOMAIN ENGINES                       │
│    PacingService    │   RevisionService   │ IngestionEngine │
│  (Beats Dilution)   │  (Forgetting Curve) │(YouTube/Markdown)│
│                     │                     │  AutoBackupMgr  │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                     LOCAL INTELLIGENCE                      │
│        LocalInferenceService (Qwen 2.5 0.5B / 1.5B GGUF)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                      PERSISTENCE LAYER                      │
│           Embedded SQLite (Foreign Keys Cascade ON)         │
│    RoadmapRepo · ChapterRepo · BeatRepo · BeatLogRepo       │
└─────────────────────────────────────────────────────────────┘
```

Detailed architectural blueprints, reactive loops, and module specifications can be found in [.agents/ARCHITECTURE.md](.agents/ARCHITECTURE.md).

---

## 🛠️ Building & Running Locally

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x stable)
- Android Studio / Xcode (with command line tools)
- Java 17 (recommended for Android Gradle builds)

### Quickstart

```bash
# 1. Clone the repository
git clone https://github.com/ImSurajx/rythem-app.git
cd rythem-app

# 2. Fetch dependencies
flutter pub get

# 3. Verify static analysis
flutter analyze

# 4. Run automated test suites (160+ tests)
flutter test

# 5. Launch the app in debug mode
flutter run
```

---

## 🤝 Contributing

Contributions are warmly welcome! To maintain software quality and release reliability, please follow these guidelines:

1. **Fork and Branch**: Work on branches following the `release/vX.Y.Z` or descriptive convention.
2. **Follow Code Guidelines**:
   - Adhere to the established obsidian glass design system, color tokens (`RythemColors`), and 12px rounded glass button standards.
   - Run `flutter analyze` to ensure zero warnings or errors.
   - Run `flutter test` to ensure all existing and new test suites pass.
3. **Signed Commits**: Always sign off your git commits using `git commit -s`.
4. **Update Changelog**: Document user-facing additions or fixes in [CHANGELOG.md](CHANGELOG.md).
5. **Open a Pull Request**: Submit your PR with a clear summary of changes and verification evidence.

---

## 📄 License

Distributed under the PolyForm Noncommercial License 1.0.0. See [LICENSE](LICENSE) for details.

---

<div align="center">
Built with care for self-directed learners everywhere.
</div>
