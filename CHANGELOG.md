# Changelog

All notable changes to this extension are documented here.

## [2.0.1] - 2026-09-03

### Fixed

- Populated core B24 placement values directly in the dialog markup as a resilient startup fallback.
- Initialized defaults before wiring secondary controls so one UI error cannot leave the form blank.
- Retried the SketchUp ready callback until the HtmlDialog bridge is available.
- Guarded favorites and recent-cabinet storage for HtmlDialog environments that restrict local storage.

## [2.0.0] - 2026-09-03

### Added

- JSON catalogs for base, wall, tall, pantry, sink, vanity, corner, and accessory cabinets.
- Automatic model defaults, project defaults, catalog search, favorites, recent models, and remembered selection.
- Stable cabinet IDs, revision metadata, seven CSV report types, full shop-drawing views, and a double-click edit tool.
- Countertop layout selection, backsplash generation, sink cutouts, and a reusable geometry part builder.

### Changed

- Project defaults flow into new cabinets while catalog and cabinet-level values remain editable.
- Existing cabinet edits regenerate in place, retain identity, and increment revision.
- Catalog codes are authoritative for new cabinets; legacy number inference remains for existing models.

### Fixed

- Restored B24 (24 x 34.5 x 24), W3018 (18 x 30 x 12), and Tall Pantry (24 x 84 x 24) defaults.
- Prevented saved dimensions from replacing the selected catalog model's standard dimensions.

## [1.1.2] - 2026-09-03

### Fixed

- Replaced Ruby `Net::HTTP` with SketchUp's native asynchronous HTTP client for update checks.
- Prevented GitHub certificate-store errors from blocking update checks in SketchUp.

## [1.1.1] - 2026-09-02

### Fixed

- Prevented incomplete legacy preferences from blanking cabinet defaults when the generator opens.
- Added browser-side fallback values so every form field is populated even when saved data is missing.

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
