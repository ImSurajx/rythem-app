# Rythem Agent Rules & Operational Standards

> **Mandatory Agent Operating System**: All AI coding agents, developers, and automated tools working on the Rythem repository MUST strictly adhere to the following rules and operational standards.

---

## 1. Step-by-Step Implementation & User Approval Rules

### 1.1 No Autonomous Full Implementations
- **DO NOT** begin implementing large features, architectural refactors, or entire multi-step stages on your own.
- **DO NOT** make assumptions or execute multiple major stages in a single pass without user alignment.

### 1.2 Granular Task Decomposition
- Always deconstruct complex tasks or features into **small, discrete, and reviewable steps**.
- Clearly state what the current single step is before writing code or running modifying commands.

### 1.3 Mandatory Checkpoints & User Permission
- Implement **only one step at a time**.
- When that single step is completed and verified:
  1. Show what was accomplished in that specific step.
  2. Stop execution immediately.
  3. **Ask the user for explicit permission** before advancing to the next step.
- Proceed to the next step **ONLY** after receiving the user's explicit approval.

---

## 2. Git Standards & Cryptographic Signing

### 2.1 Commit Sign-Off (`-s`)
- **Always** sign off on commits with Developer Certificate of Origin: `git commit -s`.
- Follow Conventional Commits format (`feat:`, `fix:`, `docs:`, `ci:`, `refactor:`, `test:`, `chore:`).
- Commit messages must be concise, descriptive, and reference modified domains accurately.

### 2.2 GPG-Signed Release Tags
- **All release tags MUST be GPG-signed** so GitHub marks them with the verified badge:
  ```bash
  git tag -s -u 90E22157F298E91B -f <tag_name> -m "Release <tag_name>"
  ```
- **Never** create or push unsigned/lightweight tags for official releases.
- Ensure GPG signature validation is verified before pushing tags to remote.

### 2.3 Strict Branch Equality & Synchronization
- The production branch (`master`) and the active release branch (e.g., `release/v1.1.9`) must **always remain strictly commit-equal**.
- When changes are made on the release branch, fast-forward merge them into `master` before pushing:
  ```bash
  git checkout master
  git merge <release_branch>
  git checkout <release_branch>
  git push origin <release_branch> master --tags -f
  ```

---

## 3. GitHub Actions CI/CD Concurrency & Scoping

### 3.1 Concurrency Guards
- Every GitHub Actions workflow must declare a concurrency cancellation group to prevent multiple redundant runs from stacking up on rapid commits:
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.sha }}
    cancel-in-progress: true
  ```

### 3.2 Workflow Trigger Scoping
- Heavy compilation workflows (such as APK releases in `release.yml`) must **only** trigger on:
  - Pushes to `master`
  - Version tags (`v*`)
  - Manual triggers (`workflow_dispatch`)
- Do not run release builds on arbitrary feature branches or documentation updates.
- Always configure `paths-ignore` for non-code files (`'**.md'`, `'docs/**'`, `'.gitignore'`, `'LICENSE'`).

---

## 4. Free, No-Signup, No-Key External APIs (Ambient Context)

### 4.1 Strict No-Key Policy
- For client-side ambient services (weather, daily quotes, geocoding), **strictly avoid any third-party service requiring paid API keys, tokens, or sign-up credentials**.
- Rythem is a privacy-first, local-first app; users must never be forced to supply API keys or subscribe to cloud accounts.

### 4.2 Approved Ambient APIs & Fallback Strategy
- **Weather**:
  - Live weather data: Open-Meteo (`https://api.open-meteo.com/v1/forecast`)
  - Reverse geocoding: BigDataCloud Client API (`https://api.bigdatacloud.net/data/reverse-geocode-client`)
  - Fallback weather: `wttr.in/?format=j1`
- **Location Granularity**:
  - Because public weather stations have ~10-15km distance variations from micro-localities, always prioritize **state / province / region** level weather (`principalSubdivision` / `region`) over micro-neighborhoods to avoid user confusion.
- **Daily Quotes & Greetings**:
  - Dynamic fetch: ZenQuotes (`https://zenquotes.io/api/today`) with fallback to DummyJSON (`https://dummyjson.com/quotes/random`).
  - **Deterministic Offline Reserve**: Always back external APIs with an offline, hardcoded 365-day quote bank keyed by day-of-year so the app remains 100% functional without internet.

---

## 5. UI/UX Design Standards & Apple-Inspired Aesthetics

### 5.1 Apple-Style Minimalism
- Avoid heavy, dark box shadows on hero icons or cards. Use crisp, subtle circular specular borders (`Colors.white24` for dark mode, `Colors.black12` for light mode).
- Prefer clean, tactile, circular raw icon buttons (`Icons.arrow_forward_rounded`, `Icons.check_rounded`) over bulky, full-width rectangular buttons.
- Keep onboarding minimal, airy, and focused on value proposition.

### 5.2 Icon Consistency
- Ensure icon choices align semantically with the task. Do not reuse disparate icons (e.g. lightning/electricity icons) where standard checklist, checkmark, or arrow icons are expected.

---

## 6. Dart & Flutter Architecture Invariants

### 6.1 Safe Platform Channel Type Casting
- Platform channel numeric values returned from native iOS/Android code can serialize as `int` or `double`.
- **Always safely cast numbers**:
  ```dart
  // Correct:
  final lat = (map['latitude'] as num?)?.toDouble();
  final count = (map['count'] as num?)?.toInt();

  // Incorrect (causes runtime type cast crashes):
  final lat = map['latitude'] as double?;
  ```

### 6.2 QA & Widget Testing Safety
- In scrollable views (`ListView`, `CustomScrollView`, `SingleChildScrollView`), always call:
  ```dart
  await tester.ensureVisible(finder);
  ```
  before calling `await tester.tap(finder)`.
- Never leave dangling SQLite database locks or unresolved periodic timers in test suites.

### 6.3 Release & Changelog Maintenance
- Whenever cutting a release, updating tags, or packaging builds:
  - Maintain and update [CHANGELOG.md](file:///Users/itsurajx/Developer/rythem-app/CHANGELOG.md) with comprehensive notes covering features, bug fixes, and architectural improvements.
  - Keep version strings in `pubspec.yaml` synchronized with GitHub release tags.
