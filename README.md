# File Organizer Pro

**Scan → Understand → Organize → Preview → Apply → Undo** — a fast, safe file
organization utility for Windows 10/11. Fully offline, no account required.

![Platform](https://img.shields.io/badge/platform-Windows%2010%2B-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.41-blueviolet)
![Version](https://img.shields.io/badge/version-1.7.0-green)
![License](https://img.shields.io/badge/license-MIT-blue)

## ✨ Features

- **📁 Folder scanning** — recursively scan any folder and view every file
  with its name, extension, size, category, and modified date
- **🔎 Search** — filter the latest scan by name, extension, path, category,
  size range, and modified-date range; open files or reveal them in Explorer
- **🧹 Automatic organization** — sort files into category folders
  (`Documents`, `Images`, `Videos`, `Audio`, `Archives`, `Applications`,
  `Code`, `Other`)
- **📏 Custom rules** — visual rule builder: *IF filename contains "invoice"
  THEN move to Documents/Invoices*, with create, edit, delete, enable/disable,
  test-rule support, absolute folder targets, and a "create folder if
  missing" option
- **👀 Safe preview** — see exactly what will move *before* anything changes
- **↩️ Undo** — every operation is recorded and can be reversed, even after
  restart
- **⧉ Duplicate finder** — groups byte-identical files using size comparison
  + SHA-256 content hashing, with safe delete behind strong confirmation
- **📈 Large file finder** — 100 MB / 500 MB / 1 GB presets or a custom size,
  sorted largest-first, with open / reveal / delete actions
- **📊 Storage analytics** — storage by category with clean bars, largest
  files, and largest folders
- **🕘 History** — a full audit trail of every move, undoable at any time
- **🚀 First-run experience** — welcome screen, then pick Downloads or any
  folder before you begin
- **🧪 Demo mode** — generate a disposable sample folder (in the OS temp
  directory) to try every feature without touching your real files
- **🗜 Archive extraction** — safely unpack zip, tar, gz and tgz files into an
  `Extracted/` folder with preview, progress and undo; path-traversal entries
  are refused and existing files are never overwritten
- **✏️ Batch rename** — rename many files at once with a pattern: find &
  replace, prefix/suffix, numbered sequences, or case conversion — every
  change previewed first, conflict-safe, and undoable
- **🎨 Appearance** — light/dark mode and accent color
- **🛡️ Safety first** — system-folder protection, conflict handling with
  `name (1).ext`, delete confirmations, overwrite protection, failure isolation
- **🧹 Cache cleaner** — clear every piece of regenerable cache (stored
  scan summaries, the demo sample folder, database journal overhead) in one
  action from *Settings → Storage*, with a live footprint and a freed-bytes
  report; history, rules and your files are never touched
- **💾 Local & private** — everything is stored in a local SQLite database;
  no internet, no telemetry, no account

## 📸 Screenshots

Coming soon — see the `screenshots/` folder once the first release is out.

## 🔧 Installation

**Download the latest Windows release from the [Releases](https://github.com/file-organizer-pro/file-organizer-pro/releases) page:**

- `FileOrganizerPro-Setup.exe` — installs the app, creates a Start Menu
  shortcut (and an optional desktop shortcut), and uninstalls cleanly while
  preserving your data
- `FileOrganizerPro-Portable.zip` — unzip and run `file_organizer_pro.exe`
  without installing anything

> **SmartScreen warning?** The releases are unsigned, so Windows may show
> "Windows protected your PC" the first time you run the installer or the
> portable exe. Click **More info** → **Run anyway** — the files are safe.
> See the FAQ below for details.

### From source (Windows 10/11)

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows) (stable channel)
2. Install [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/)
   with the **Desktop development with C++** workload
3. Clone the repository and run:

```powershell
flutter pub get
flutter run -d windows
```

To build a release executable:

```powershell
flutter build windows --release
```

The app is at `build/windows/x64/runner/Release/file_organizer_pro.exe`. To
produce the installer and portable ZIP locally, see
[`tool/build_release.ps1`](tool/build_release.ps1) (requires Visual Studio
2022 with the C++ workload).

### Releasing in CI

No local toolchain needed — this repo ships a
[GitHub Actions workflow](.github/workflows/release.yml) that builds both
artifacts on a hosted Windows runner (VS 2022 + C++ is preinstalled) and
attaches them to a Release. Push a version tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

The workflow runs `flutter analyze` + `flutter test`, builds the release,
produces `FileOrganizerPro-Setup.exe` (Inno Setup) and
`FileOrganizerPro-Portable.zip`, and creates the GitHub Release with both
files. You can also trigger it manually from the *Actions* tab to fetch the
artifacts without creating a Release.

## 🚀 How to use

1. **Welcome** — on first launch, choose your folder (Downloads by default) or
   pick *Try demo data* to explore safely
2. **Scan** — open the *Scan* tab, pick a folder, press *Scan*
3. **Understand** — the dashboard shows totals; the scan table supports search,
   filters, and sorting
4. **Preview** — open the *Organize* tab and press *Preview changes* to see the
   full move plan (custom rules apply automatically)
5. **Apply** — press *Apply changes*; conflicts get a ` (1)` suffix instead of
   overwriting
6. **Rename** — open the *Rename* tab, pick a pattern (find & replace,
   prefix/suffix, numbering, case), preview the new names, and apply
7. **Undo** — from the *History* tab, press *Undo Last Operation* to reverse
   the most recent batch — any time, even after restart

## 🛡️ Safety

- Organizing **Windows, Program Files**, and other system folders is blocked by
  default (toggle in *Settings → Safety*)
- Existing files are never overwritten — a unique name is chosen instead
- Deleting duplicates or large files always requires explicit confirmation
- Every move is written to the operation history before it can be reversed
- If a file is locked or unreadable, the operation continues with the rest and
  reports the failures

See [SECURITY.md](SECURITY.md) for the full privacy and safety policy.

## 🏗️ Architecture

The app follows a clean, layered structure:

```
lib/
├── main.dart              # entry point, service initialization
├── app.dart               # root widget, theme wiring, first-run routing
├── core/
│   ├── app_controller.dart    # central state (ChangeNotifier)
│   ├── database_service.dart   # SQLite storage (scans, history, rules)
│   └── file_utils.dart         # size/date formatting, shell helpers
├── models/                # category, scanned file, scan result, operations,
│                          #   custom rules, duplicate groups
├── services/
│   ├── scanner_service.dart    # recursive folder scan with progress
│   ├── organizer_service.dart  # move plan, rules, apply, conflicts, undo
│   ├── rename_service.dart     # batch rename patterns, conflicts, undo
│   ├── duplicate_service.dart  # SHA-256 duplicate detection
│   ├── demo_service.dart       # disposable sample folder in temp
│   └── settings_service.dart   # persisted preferences
├── screens/               # dashboard, scan, organize, duplicates, large files,
│                          #   rules, storage, history, settings, onboarding
├── theme/                 # Material 3 light/dark themes
└── widgets/               # reusable UI pieces

tool/
├── build_release.ps1      # portable ZIP + optional installer build
└── installer.iss          # Inno Setup script (FileOrganizerPro-Setup.exe)
```

## 🗺️ Roadmap

| Milestone | Status |
| --- | --- |
| MVP 1 — Scanner → Dashboard → Organizer | ✅ done |
| MVP 2 — Custom Rules → Preview → Undo | ✅ done |
| MVP 3 — Duplicate Finder (SHA-256) → Large File Finder | ✅ done |
| MVP 4 — Storage Analytics → History → Settings | ✅ done |
| MVP 5 — Testing → Docs → Release | ✅ v1.0.0 released |
| v1.1.0 — Archive extraction + per-rule folder options | ✅ released |
| v1.2.0 — Batch rename (patterns, preview, undo) | ✅ released |
| v1.3.0 — Search performance (debounce + isolate + virtualized table) | ✅ released |
| v1.4.0 — Cache clearer (Settings → Storage) | ✅ released |
| v1.5.0 — Dashboard Storage section (cache footprint) | ✅ released |
| v1.6.0 — Storage bar chart (cache vs history vs rules) | ✅ released |
| v1.7.0 — Cache cleaner (all regenerable cache, freed-bytes report) | ✅ released |

Planned next: 7z/rar extraction, more scan filters (owner, hidden files),
archive-in-archive handling, and a portable settings export/import.

## 🧪 Testing

```powershell
flutter test
```

Covers extension classification, custom rule matching, folder scanning
(nested files, empty folders, unreadable entries), duplicate detection against
real files, plan building with rules, conflict resolution, and the undo cycle.

## ❓ FAQ

**Does it need an internet connection?** No. It works fully offline.

**Does it collect my files?** No. Nothing is uploaded; paths and metadata are
stored in a local SQLite database only.

**Can it delete my files by mistake?** The app never deletes automatically.
Deletion is always behind an explicit, permanent-deletion confirmation.

**Can I undo an organization after restarting?** Yes. Moves are persisted to
the history and can be reversed at any time.

**Is organizing a system folder allowed?** Only if you explicitly disable
system-folder protection in Settings — it is on by default.

**Windows shows "Windows protected your PC" when I run the exe — is it
safe?** Yes. The release binaries are not code-signed — signing certificates
cost money and this is a free, open-source project — so Windows can't verify
the publisher and shows a warning instead. Click **More info** → **Run
anyway** to proceed. The files are scanned clean by Windows Defender, the
app is fully open source, works offline, and never moves or deletes a file
without showing you a preview first.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## 📜 License

Released under the MIT License — see [LICENSE](LICENSE).
