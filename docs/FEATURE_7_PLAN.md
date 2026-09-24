# Architectural Implementation Plan — Feature 7: In-App GitHub Releases Updater & Modal Sheet

## 1. Executive Summary & Problem Context
Rythem is a local-first learning operating system distributed primarily via GitHub Releases (APK for Android, desktop packages). Currently, users have to manually visit the GitHub repository in a browser to check for updates, download APKs, and manually locate them in file managers to install.

**Feature 7** introduces a self-contained in-app updater accessible right from the **Settings** screen, featuring:
1. **GitHub Releases API & SemVer Engine**: Lightweight, fast check against `api.github.com/repos/ImSurajx/rythem-app/releases/latest` with robust semver parsing (`v1.0.1+2` vs `v1.0.2+3`).
2. **Glassmorphic Update Modal Sheet**: Premium liquid glass bottom sheet displaying version bump chips (`v1.0.1` ➔ `v1.0.2`), APK package size, publish timestamp, scrollable markdown changelog, and live streaming download progress bar.
3. **Chunked Streaming Download Engine**: Real-time byte tracking, speed calculation, cancellation support, and integrity verification.
4. **Native Android Package Installer**: Zero third-party dependency MethodChannel in `MainActivity.kt` utilizing Android's `FileProvider` and `canRequestPackageInstalls()` permission flow, with graceful desktop/browser fallback via `url_launcher`.

---

## 2. Proposed Architecture & Component Design

```
lib/
├── core/
│   └── updater/
│       ├── models/
│       │   ├── semver.dart                 // Semantic version parsing & comparison
│       │   ├── update_release_info.dart    // Release metadata, APK asset details, changelog
│       │   └── download_progress.dart      // Live byte progress, percentage, status, speed
│       └── services/
│           ├── github_release_service.dart // API check & streaming chunked APK download
│           └── native_installer_service.dart // Platform channel bridge to Android PackageInstaller
└── features/
    └── settings/
        └── widgets/
            ├── software_update_card.dart   // Settings screen card with version & update badge
            └── update_modal_sheet.dart     // Liquid glass modal with changelog & progress bar
```

---

## 3. Detailed Component Specifications

### A. Semantic Version Engine (`core/updater/models/semver.dart`)
- Parses version strings conforming to `vMajor.Minor.Patch+Build` (e.g. `v1.0.1+2`, `1.0.2`, `1.2.0-beta`).
- Strips leading `v` or `V`.
- Separates version components (`major`, `minor`, `patch`) from build number (`build`).
- Implements `Comparable<SemVer>`:
  - If major differs: comparison based on major.
  - If minor differs: comparison based on minor.
  - If patch differs: comparison based on patch.
  - If versions are identical: comparison based on build number (if present).
  - Operator overrides: `<`, `<=`, `>`, `>=`, `==`.

### B. Release Models (`core/updater/models/update_release_info.dart` & `download_progress.dart`)
- **`UpdateReleaseInfo`**:
  - `tagName`: e.g. `"v1.0.2"`.
  - `semVer`: parsed `SemVer` instance.
  - `title`: e.g. `"Rythem v1.0.2 - Revision Shelf & Performance Boost"`.
  - `releaseNotes`: Markdown body from GitHub release.
  - `publishedAt`: `DateTime`.
  - `apkUrl`: Direct download URL for `.apk` asset.
  - `apkName`: e.g. `"app-release.apk"`.
  - `apkSizeBytes`: Size in bytes (formatted helper: `24.5 MB`).
  - `htmlUrl`: Web URL to release page on GitHub.
  - `isUpdateAvailable`: boolean flag against current app version.
- **`UpdateDownloadProgress`**:
  - `status`: `idle`, `downloading`, `completed`, `cancelled`, `error`.
  - `bytesDownloaded`: integer.
  - `totalBytes`: integer.
  - `progress`: float from $0.0$ to $1.0$.
  - `speedBytesPerSec`: integer.
  - `savedFilePath`: String.
  - `errorMessage`: String?.

### C. GitHub Release Service (`core/updater/services/github_release_service.dart`)
- **Repository Constants**:
  - Default repo: `ImSurajx/rythem-app`.
  - Endpoint: `https://api.github.com/repos/ImSurajx/rythem-app/releases/latest`.
- **`checkForUpdate({String? currentVersionOverride, http.Client? client})`**:
  - Makes GET request with `Accept: application/vnd.github.v3+json`.
  - Inspects assets for `.apk` (or fallback to browser release URL).
  - Compares parsed release tag with current app version (`1.0.1+2` from `AppInfo` or pubspec).
  - Returns `UpdateReleaseInfo`.
- **`downloadApkStream({required String apkUrl, required String savePath, http.Client? client})`**:
  - Uses `client.send(http.Request('GET', Uri.parse(apkUrl)))`.
  - Streams chunks into `File(savePath)` via `IOSink`.
  - Emits `UpdateDownloadProgress` updates (throttled to ~100ms or 1% increments).
  - Supports cancellation via `CancellationToken`.

### D. Native Android Installer (`core/updater/services/native_installer_service.dart`)
- Uses `MethodChannel('com.rythem.rythem_app/updater')`.
- Methods:
  1. `canRequestPackageInstalls()`: returns bool.
  2. `openInstallPermissionSettings()`: opens system settings to allow unknown source install for Rythem.
  3. `installApk(String filePath)`: starts package installer intent with `FileProvider`.
- Non-Android / Desktop Fallback:
  - If `!Platform.isAndroid`: uses `url_launcher` to launch GitHub release URL or download link in browser.

### E. Android Native Configuration
- **`android/app/src/main/AndroidManifest.xml`**:
  - `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />`
  - Register `FileProvider`:
    ```xml
    <provider
        android:name="androidx.core.content.FileProvider"
        android:authorities="${applicationId}.fileprovider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
    </provider>
    ```
- **`android/app/src/main/res/xml/file_paths.xml`**:
  - Cache, external, and app files paths configuration.
- **`android/app/src/main/kotlin/com/rythem/rythem_app/MainActivity.kt`**:
  - Wire MethodChannel handlers for permission check, settings launch, and `ACTION_VIEW` intent.

### F. Glassmorphic UI Components
- **`UpdateModalSheet`** (`features/settings/widgets/update_modal_sheet.dart`):
  - Liquid glass aesthetic: `BackdropFilter(sigma: 16)`, rounded corners (24r), glass borders.
  - Header:
    - Gradient version bump pill: `v1.0.1` ➔ `v1.0.2`.
    - Package metadata: size (e.g., `24.8 MB`), release date (`Sep 24, 2026`).
  - Changelog Card:
    - Formatted markdown changelog with bullet points, headers, and code tags.
  - Download Progress Section:
    - Animated progress bar (`LinearProgressIndicator` with frosted styling).
    - Real-time readout: `45% (11.2 MB / 24.8 MB) • 2.4 MB/s`.
  - Actions:
    - Initial: `Download & Install` (Primary) + `Later` (Secondary).
    - Downloading: `Cancel Download` (Secondary).
    - Downloaded: `Install Now` (Primary, icon: `Icons.system_update_rounded`).
    - Up to Date: `You're up to date! (v1.0.1)` + `Close`.
- **`SoftwareUpdateCard`** (`features/settings/widgets/software_update_card.dart`):
  - Located on Settings tab.
  - Displays: Current Version, Status ("Up to date" or "Update Available").
  - `Check for Updates` button triggers check and opens modal.

---

## 4. Step-by-Step Implementation Sequence

1. **Step 1: Data Models & SemVer Logic**
   - Create `lib/core/updater/models/semver.dart`.
   - Create `lib/core/updater/models/update_release_info.dart`.
   - Create `lib/core/updater/models/download_progress.dart`.
   - Write comprehensive unit tests for SemVer parsing and comparison in `test/semver_test.dart`.

2. **Step 2: GitHub Release & Download Service**
   - Create `lib/core/updater/services/github_release_service.dart`.
   - Implement `checkForUpdate` and `downloadApkStream`.
   - Write tests with mocked HTTP clients in `test/github_release_service_test.dart`.

3. **Step 3: Native Android Installer Platform Bridge**
   - Create `lib/core/updater/services/native_installer_service.dart`.
   - Update `android/app/src/main/AndroidManifest.xml` (add permission & `FileProvider`).
   - Create `android/app/src/main/res/xml/file_paths.xml`.
   - Update `android/app/src/main/kotlin/com/rythem/rythem_app/MainActivity.kt` with MethodChannel.

4. **Step 4: UI Components & Settings Screen Integration**
   - Create `lib/features/settings/widgets/update_modal_sheet.dart`.
   - Create `lib/features/settings/widgets/software_update_card.dart`.
   - Integrate `SoftwareUpdateCard` into Settings tab in `lib/main.dart`.

5. **Step 5: Verification & Testing**
   - Run `flutter analyze` ensuring 0 warnings/lints.
   - Run unit and widget test suites.
   - Run full app regression suite (`flutter test`).
   - Update `docs/NEW_ARCHITECTURE_ROADMAP.md` and walkthrough artifact.

---

## 5. Verification Plan

### Automated Test Cases
1. **SemVer Comparison Tests** (`test/semver_test.dart`):
   - Patch release: `1.0.1` < `1.0.2`.
   - Minor release: `1.0.1` < `1.1.0`.
   - Major release: `1.0.1` < `2.0.0`.
   - Build numbers: `1.0.1+2` < `1.0.1+3`.
   - `v` prefix tolerance: `v1.0.2` == `1.0.2`.
   - Equal and downgrade versions.
2. **GitHub Release Service Tests** (`test/github_release_service_test.dart`):
   - Fetching latest release parses `.apk` asset URL, size, title, and body.
   - Accurately reports `isUpdateAvailable: true` when remote is higher.
   - Accurately reports `isUpdateAvailable: false` when remote is equal or lower.
   - Streaming download reports chunked byte progress and writes file to disk.
3. **UI Widget Tests** (`test/software_update_ui_test.dart`):
   - `SoftwareUpdateCard` displays current version and triggers modal on tap.
   - `UpdateModalSheet` displays version bump badge, markdown changelog, progress bar, and action buttons.
4. **Full Regression Test**:
   - `flutter test` across all 196+ existing tests.
   - `flutter analyze` with 0 issues.
