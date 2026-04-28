#!/usr/bin/env bash
set -euo pipefail

# Update launcher icons from a single PNG image.
# Usage: ./tools/update_launcher_icons.sh path/to/icon.png

ICON_SOURCE="${1-}"
if [[ -z "$ICON_SOURCE" ]]; then
  if [[ -f "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" ]]; then
    echo "No source provided. Using macOS AppIcon as fallback."
    ICON_SOURCE="macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"
  else
    echo "Usage: $0 path/to/icon.png" >&2
    exit 1
  fi
fi

DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/icons"
mkdir -p "$DEST_DIR"
cp "$ICON_SOURCE" "$DEST_DIR/app_icon.png"
echo "Installed icon to $DEST_DIR/app_icon.png"

# If no source provided, try macOS app icon as fallback
if [[ ! -f "$ICON_SOURCE" ]]; then
  if [[ -f "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" ]]; then
    echo "No source image provided. Using macOS AppIcon as fallback."
    cp "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" "$DEST_DIR/app_icon.png"
  else
    echo "No source image provided and no macOS AppIcon found as fallback." >&2
    exit 2
  fi
  ICON_SOURCE="$DEST_DIR/app_icon.png"
fi

echo "Installing dependencies and generating launcher icons..."
flutter pub get
flutter pub run flutter_launcher_icons:main

echo "Launcher icons updated."
