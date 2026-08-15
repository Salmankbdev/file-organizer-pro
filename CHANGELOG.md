# Changelog

All notable changes to File Organizer Pro are documented here.

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
