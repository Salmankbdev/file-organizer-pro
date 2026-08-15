# Contributing to File Organizer Pro

Thanks for your interest! Here's how to get started.

## Development setup

1. Install [Flutter](https://docs.flutter.dev/get-started/install/windows) and Visual Studio 2022 (Desktop development with C++ workload)
2. Clone the repo, then:

```powershell
flutter pub get
flutter analyze
flutter test
```

## Code style

- Follow the project's conventions — `flutter analyze` must pass with zero issues
- Keep the layered structure: models → services → controllers → screens
- Add a test for every behavior you touch in `services/` or `models/`
- Don't add dependencies unless the feature genuinely needs them

## Making changes

1. Fork the repository and create a branch
2. Make your change and add tests
3. Run `flutter analyze` and `flutter test`
4. Open a pull request describing what and why

## Reporting bugs

Include: OS version, Flutter version, the folder you scanned (or a minimal repro), and the expected vs. actual behavior.
