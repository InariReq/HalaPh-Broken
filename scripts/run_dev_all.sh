#!/usr/bin/env bash
set -euo pipefail

# Runs local mock backend, iOS app on a connected device, and macOS app in parallel.
# Usage: ./scripts/run_dev_all.sh <DEVICE_ID>

DEVICE_ID="${1:-}"

if [ -z "$DEVICE_ID" ]; then
  # Try to auto-detect a connected iOS device
  DEVICE_ID=$(flutter devices | awk '/connected device/ {print $1; exit}' || true)
fi

if [ -z "$DEVICE_ID" ]; then
  echo "No connected iOS device detected. Please connect your iPhone and ensure it is trusted."
  echo "You can also pass the device ID as the first argument."
  exit 1
fi

echo "Starting local mock backend (port 8080)..."
if pgrep -f 'dart bin/local_backend.dart' > /dev/null; then
  echo "Local backend already running."
else
  nohup dart bin/local_backend.dart > /tmp/local_backend.log 2>&1 &
  echo $! > /tmp/local_backend.pid
fi

echo "Launching iOS app on device $DEVICE_ID..."
osascript << 'OSAS'
tell application "Terminal"
  do script "flutter run -d ${DEVICE_ID}"
end tell
OSAS

echo "Launching macOS app..."
osascript << 'OSAS2'
tell application "Terminal"
  do script "flutter run -d macos"
end tell
OSAS2
