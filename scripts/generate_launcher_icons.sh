#!/usr/bin/env bash
set -euo pipefail
echo "Generating launcher icons from assets/icon/app_icon.png..."
flutter pub get
flutter pub run flutter_launcher_icons:main
echo "Launcher icons updated."
