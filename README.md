# HalaPH

HalaPH is a Flutter trip-planning app focused on destinations and route discovery in the Philippines.

## Getting Started

1. Install Flutter.
2. Run `flutter pub get`.
3. Start the app with `flutter run`.

## Google Maps Setup

This repository does not store any live API keys.

For Dart-powered Google API calls, pass your key at runtime:

```bash
flutter run --dart-define=MAPS_API_KEY=your_key_here
```

For Android builds, set an environment variable before running Flutter:

```powershell
$env:MAPS_API_KEY="your_key_here"
flutter run
```

For iOS builds, create a local file at `ios/Flutter/Secrets.xcconfig` with:

```text
MAPS_API_KEY = your_key_here
```

That file is ignored by Git so your key stays local.

## GitHub Automation

This repo includes:

- Flutter CI on pushes and pull requests
- Dependabot updates for Dart packages and GitHub Actions
- Automatic merge for safe Dependabot patch/minor updates after CI passes
Run on iPhone and macOS for local DB inspector and app development

- Prerequisites: Xcode, Flutter, gh, a connected iPhone, macOS development environment
- Quick run: use the script to launch both iPhone app and macOS inspector along with the local mock backend:
- bash scripts/run_dev_all.sh <DEVICE_ID>
# HalaPh-Broken
# HalaPh-Main
# HalaPh-Main
