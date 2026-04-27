#!/usr/bin/env bash
set -euo pipefail

# Update launcher icons from a single PNG image.
# Usage: ./tools/update_launcher_icons.sh path/to/icon.png

ICON_SOURCE="${1-}"
if [[ -z "$ICON_SOURCE" ]]; then
  echo "Usage: $0 path/to/icon.png"
  exit 1
fi

DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/icons"
mkdir -p "$DEST_DIR"
cp "$ICON_SOURCE" "$DEST_DIR/app_icon.png"
echo "Installed icon to $DEST_DIR/app_icon.png"

echo "Installing dependencies and generating launcher icons..."
flutter pub get
flutter pub run flutter_launcher_icons:main

echo "Launcher icons updated."
