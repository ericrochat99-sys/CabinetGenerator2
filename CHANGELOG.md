# Changelog

All notable changes to this extension are documented here.

## [1.1.0] - 2026-09-02

### Added

- Automatic daily update checks against the latest public GitHub Release.
- Manual **Check for Updates…** command in the extension menu.
- Trusted release-page prompt when a newer semantic version is available.

### Changed

- Updated the extension version to `1.1.0`.

## [1.0.0] - 2026-09-02

### Added

- Production SketchUp extension registration and loader.
- Separate HTML, CSS, and JavaScript assets for cabinet, settings, and report dialogs.
- Deterministic RBZ build and package validation.
- GitHub Actions validation, artifact, and tagged-release workflow.

### Changed

- Namespaced cabinet catalog and generator code under `SkilledServices`.
- Centralized the extension version in `skilled_services/version.rb`.

### Fixed

- Corrected the menu guard so successful initialization cannot duplicate menus on reload.
