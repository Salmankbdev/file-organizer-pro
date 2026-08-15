# Security & Privacy

File Organizer Pro is designed to be safe for your files and private by
default. This document explains the guarantees we make and how to report a
security issue.

## Privacy

- **100% offline.** The application makes no network requests. There is no
  telemetry, no analytics, and no crash reporting by default.
- **No account, no cloud.** Nothing is uploaded anywhere. Your files never
  leave your computer.
- **Local storage only.** Scan summaries, custom rules, preferences, and
  operation history are stored in a local SQLite database inside the
  application-support folder on your machine. The app never copies your
  files' contents into the database — only paths and metadata.

## File safety

- **No automatic deletion.** The app never deletes files on its own.
  Deleting duplicates or large files always requires your explicit
  confirmation, and the dialog makes clear the action is permanent.
- **Preview before moving.** Organization is never applied without a preview
  of every planned move and an explicit *Apply changes* action.
- **Undo.** Every move is recorded in the operation history and can be
  reversed, including after restarting the app.
- **No silent overwrites.** When a target name already exists, the app
  chooses a unique name (`name (1).ext`) instead of replacing anything.
- **System-folder protection.** Organizing `C:\Windows`, `Program Files`,
  `ProgramData`, the Recycle Bin, and other system locations is blocked by
  default. You can toggle this in *Settings → Safety*.
- **Failure isolation.** If a file is locked, missing, or unreadable, the
  operation continues with the remaining files and the failure is reported
  instead of aborting everything.

## Reporting a vulnerability

Please do **not** open a public issue for security problems. Instead, email
the maintainers (address in `CONTRIBUTING.md`) with:

1. A description of the issue and its impact,
2. Steps to reproduce,
3. The app version and Windows version you tested on.

We aim to acknowledge reports within 5 business days and to ship a fix as
part of the next release once confirmed.

## Supported versions

Security fixes are backported to the latest stable release. Users are
encouraged to always run the newest version from the
[Releases](https://github.com/file-organizer-pro/file-organizer-pro/releases)
page.
