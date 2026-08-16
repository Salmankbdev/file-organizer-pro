# Changelog

All notable changes to File Organizer Pro are documented here.

## [1.3.0] - 2026-08-16

### Performance
- **Search no longer freezes the app**: typing is debounced (250 ms) and
  filtering + sorting run on a **background isolate**, so the UI stays at
  60 fps even with tens of thousands of files (a 100k-file filter+sort is
  ~125 ms of CPU, previously executed synchronously on the UI thread on
  every keystroke)
- The results table is now **virtualized** — only the rows visible in the
  viewport are built, so huge result sets render instantly and scroll
  smoothly (previously every row widget was built eagerly, which froze the
  UI on large folders)
- Scan / organize / duplicate / extract / rename **progress updates are
  throttled** to ~10 per second instead of firing once per file, cutting
  rebuild flood on big folders
- Large-file finder filters and sorts on a background isolate too
- Organize preview builds only the visible move rows per category
- New isolate-ready, unit-tested filter service (`scan_filter.dart`) with
  10 new tests covering query, category, size range, date range and sort
  combinations
- Version bumped to 1.3.0

## [1.2.2] - 2026-08-16

### Fixed
- **Installed app failed to start** ("Can't load AOT data from …\data\app.so")
  — the build script's installer staging re-copied the build with PowerShell's
  `Copy-Item`, which flattened the `data\` folder (containing `app.so`,
  `icudtl.dat` and `flutter_assets`) into the install root, so the Flutter
  engine had nothing to load. Every installer since v1.0.0 was affected;
  the portable ZIP was not
- Staging now uses `robocopy` (exact tree copy), stages once, and packs the
  same folder into both the ZIP and the installer — the `data\` structure is
  guaranteed intact
- Version bumped to 1.2.2

## [1.2.1] - 2026-08-16

### Added
- Settings → **About** section explaining the Windows SmartScreen
  ("Windows protected your PC") warning: the release binaries are unsigned,
  so Windows cannot verify the publisher — click **More info → Run anyway**;
  the files are safe, offline and Defender-scanned
- README installation notes and FAQ now carry the same guidance

### Fixed
- Settings footer showed a stale version number; it now matches the release
- Version bumped to 1.2.1

## [1.2.0] - 2026-08-16

### Added
- **Batch rename** (new Rename section): rename many files at once with a
  pattern — find & replace (case-sensitive, all or first occurrence), add
  prefix or suffix, number files with a start value and padding, and case
  conversion (lowercase / uppercase / title case)
- Every rename is previewed first (with conflict warnings), never overwrites
  an existing file (a ` (1)` suffix is used instead), and can be undone from
  the History screen; rename batches are recorded as first-class history
  entries
- Dashboard quick action for Batch Rename

### Changed
- Navigation rail expanded to ten sections (Dashboard, Scan, Organize,
  Rename, Duplicates, Large Files, Rules, Storage, History, Settings)
- History screen distinguishes Rename / Rename undo from organize moves
- Version bumped to 1.2.0

## [1.1.0] - 2026-08-15

### Added
- **Archive extraction** (Organize → Extract archives): safely unpacks zip,
  tar, gz and tgz files into an `Extracted/` folder with preview, progress,
  and undo (removes the extracted files and empty folders)
- Extraction safety: path-traversal entries (`..`, absolute paths, symlinks)
  are refused, existing files are never overwritten (a ` (1)` suffix is used)
- **Per-rule folder options**: rules can target an absolute folder outside the
  scanned root, and each rule has a "create folder if missing" toggle — when
  off, matching files only move if the folder already exists, otherwise they
  fall through to the default category
- Protected-system-folder rules (e.g. a target inside `C:\Windows`) are
  skipped automatically while system-folder protection is enabled
- History now records extraction operations and their reversal

### Changed
- Rules editor: folder picker for absolute targets and the create-folder
  toggle; Organize screen now has Organize / Extract archive modes
- Database schema v3 (rules `create_folder`, operations `details`)
- Version bumped to 1.1.0

## [1.0.0] - 2026-08-15

### Added
- First-run welcome screen with folder selection (Downloads default)
- Demo mode: a disposable sample folder in the OS temp directory lets users
  try every feature without touching real files
- Duplicate finder: size grouping + SHA-256 content hashing, group overview,
  per-file selection, and permanent deletion behind a strong confirmation
- Large-file finder: 100 MB / 500 MB / 1 GB presets, custom size, sorted
  results with open / reveal / delete actions
- Custom rules: visual rule builder (IF extension/file-name condition THEN
  move to folder) with create, edit, delete, enable/disable, and test-rule
  support; rules are applied before the default category mapping
- Storage analytics: per-category storage bars, largest files, largest folders
- Search: filter the latest scan by name, extension, path, category, size
  range, and modified-date range; open files or reveal them in Explorer
- Settings → Storage: clear operation history and reset all settings
- Release tooling: `tool/build_release.ps1` (portable ZIP + optional
  Inno Setup installer), `tool/installer.iss`, and a GitHub Actions
  workflow (`.github/workflows/release.yml`) that builds both artifacts in
  CI and attaches them to tagged Releases
- SECURITY.md with privacy and file-safety guarantees

### Changed
- Navigation rail expanded to nine sections (Dashboard, Scan, Organize,
  Duplicates, Large Files, Rules, Storage, History, Settings)
- Path comparisons are separator- and case-robust on Windows
- Version bumped to 1.0.0

### Fixed
- Mixed `/` vs `\` path separators no longer break "already organized"
  detection

## [0.1.0] - 2026-08-15

### Added
- Folder scanner with live progress, filters, and sorting
- Dashboard with totals (files, storage, organized, last scan) and quick actions
- Organizer with move-plan preview, apply with progress bar, and conflict handling
- Operation history with one-click undo of the last batch
- Settings: default folder, auto-scan on start, confirmations, light/dark mode,
  accent color, safety toggles
- SQLite persistence for scan summaries and operation history
- System-folder protection and overwrite protection
- Tests for categories, scanning, organizing, conflicts, and undo
