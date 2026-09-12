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
- Smoke test verifying the monochrome liquid glass baseline screen.
