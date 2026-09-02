# Skilled Services – Euro Cabinet Generator

A SketchUp extension for creating configurable European-style cabinets, adding countertops, producing shop-drawing scenes, and generating cabinet reports.

## Compatibility

- SketchUp 2024 and newer
- Windows and macOS
- No third-party Ruby gems required at runtime

## Installation

1. Download `skilled-services-1.0.0.rbz` from the release.
2. In SketchUp, open **Extensions → Extension Manager**.
3. Choose **Install Extension**.
4. Select the downloaded `.rbz` file and approve the installation.
5. Open **Extensions → Euro Cabinet Generator** to use the extension.

## Project structure

- `skilled_services.rb` registers the extension with SketchUp.
- `skilled_services/main.rb` contains cabinet/model operations and dialog callbacks.
- `skilled_services/ui/` contains reusable dialog templates and separate HTML, CSS, and JavaScript assets (`index.html`, `styles.css`, and `app.js`).
- `skilled_services/version.rb` is the authoritative version source.
- `scripts/build_rbz.rb` builds a deterministic installable package.

All extension Ruby objects are namespaced under `SkilledServices`.

## Development and build

Validate Ruby syntax and build from the repository root:

```bash
ruby -c skilled_services.rb
find skilled_services -name "*.rb" -print0 | xargs -0 -n1 ruby -c
ruby scripts/build_rbz.rb
unzip -t dist/skilled-services-1.0.0.rbz
```

The builder stages only runtime files, validates required paths, rejects development or secret-like filenames, and writes `dist/skilled-services-<version>.rbz` without a parent directory.

## Releases

Update `SkilledServices::VERSION` using semantic versioning and add the release to `CHANGELOG.md`. Merge the exact release source into `main`, then create a matching tag such as `v1.0.0`. GitHub Actions validates and packages pushes to `main`; a matching version tag also publishes the RBZ to the GitHub Release.

Installing a newer RBZ is currently a manual process. SketchUp does not automatically update this extension from GitHub.
