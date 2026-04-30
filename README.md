# HalaPH

HalaPH is a Flutter trip-planning app focused on destinations and route discovery in the Philippines.

## Getting Started

1. Install Flutter.
2. Run `flutter pub get`.
3. Start the app with `flutter run`.

## Google Maps SDK Setup

This repository does not store any live API keys.

HalaPH uses Firebase Firestore for app data and Google Maps SDK for map
display. Google Places is optional for richer place listings and photos; if the
key or API is unavailable, the app falls back to OpenStreetMap/Wikipedia data.
The app does not use Google Directions or Google Geocoding web APIs.

For Android map rendering, set an environment variable before running Flutter:

```powershell
$env:MAPS_API_KEY="your_key_here"
flutter run
```

For other shells:

```bash
export MAPS_API_KEY="your_key_here"
flutter run
```

For iOS builds, create a local file at `ios/Flutter/Secrets.xcconfig` with:

```text
MAPS_API_KEY = your_key_here
```

That file is ignored by Git so your key stays local.

For Dart-side Google Places requests, provide either `MAPS_API_KEY` or
`GOOGLE_PLACES_API_KEY` in `.env` or with `--dart-define`. Google Places API
availability and billing behavior are controlled by Google Maps Platform for
the key's project.

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
