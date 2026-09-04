# ForgeCase

A SketchUp extension for creating configurable European-style cabinets from a JSON catalog, adding countertops, producing shop-drawing scenes, and generating production reports.

## Compatibility

- SketchUp 2024 and newer
- Windows and macOS
- No third-party Ruby gems required at runtime

## Installation

1. Download the latest `forgecase-<version>.rbz` from the [Releases page](https://github.com/ericrochat99-sys/CabinetGenerator2/releases/latest).
2. In SketchUp, open **Extensions → Extension Manager**.
3. Choose **Install Extension**.
4. Select the downloaded `.rbz` file and approve the installation.
5. Open **Extensions → ForgeCase** to use the extension.

## Project structure

- `skilled_services.rb` registers the extension with SketchUp.
- `skilled_services/main.rb` coordinates cabinet/model operations and dialog callbacks.
- `skilled_services/catalog/` contains editable JSON cabinet families and the catalog loader.
- `skilled_services/settings/`, `geometry/`, and `reports/` contain project defaults, reusable builders, and report services.
- `skilled_services/services/update_checker.rb` checks the official GitHub Releases API for newer versions.
- `skilled_services/ui/` contains reusable dialog templates and separate HTML, CSS, and JavaScript assets (`index.html`, `styles.css`, and `app.js`).
- `skilled_services/version.rb` is the authoritative version source.
- `scripts/build_rbz.rb` builds a deterministic installable package.

ForgeCase retains its legacy internal Ruby namespace for upgrade compatibility.

## Development and build

Validate Ruby syntax and build from the repository root:

```bash
ruby -c skilled_services.rb
find skilled_services -name "*.rb" -print0 | xargs -0 -n1 ruby -c
ruby scripts/build_rbz.rb
unzip -t dist/forgecase-1.1.0.rbz
```

The builder stages only runtime files, validates required paths, rejects development or secret-like filenames, and writes `dist/forgecase-<version>.rbz` without a parent directory.

## Releases

Update `SkilledServices::VERSION` using semantic versioning and add the release to `CHANGELOG.md`. Merge the exact release source into `main`, then create a matching tag such as `v1.0.0`. GitHub Actions validates and packages pushes to `main`; a matching version tag also publishes the RBZ to the GitHub Release.

## Update checks

The extension checks the latest public GitHub Release once per day after SketchUp starts. You can also run **Extensions → ForgeCase → Check for Updates…** at any time. When a newer semantic version is available, the extension offers to open the trusted GitHub release page. Installation remains user-controlled through SketchUp Extension Manager; the updater never downloads or executes remote Ruby code.
