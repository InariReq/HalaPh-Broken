#!/usr/bin/env bash
set -euo pipefail

# CI key injector: writes API keys into platform-specific locations
export MAPS_API_KEY="${MAPS_API_KEY:-}"

echo "[CI] Injecting Google Maps API keys into the project..."

# Dart/.env for Flutter REST API usage
if [[ -n "${MAPS_API_KEY}" ]]; then
  echo "MAPS_API_KEY=${MAPS_API_KEY}" > .env
  echo "[CI] Written .env with MAPS_API_KEY"
else
  echo "[CI] MAPS_API_KEY not set; skipping .env write"
fi

# Android: values/strings.xml key for Google Maps (android/app/src/main/res/values/strings.xml)
ANDROID_STRINGS_PATH="android/app/src/main/res/values/strings.xml"
if [[ -n "${MAPS_API_KEY}" && -f "$ANDROID_STRINGS_PATH" ]]; then
  sed -i.bak "s#<string name=\"google_maps_api_key\">.*</string>#<string name=\"google_maps_api_key\">${MAPS_API_KEY}</string>#" "$ANDROID_STRINGS_PATH" 
  echo "[CI] Updated Android maps key in $ANDROID_STRINGS_PATH"
fi

# iOS: write to the placeholder file in the iOS Runner
IOS_KEY_PATH="ios/Runner/GOOGLE_MAPS_API_KEY.txt"
IOS_SECRETS_PATH="ios/Flutter/Secrets.xcconfig"
if [[ -n "${MAPS_API_KEY}" ]]; then
  mkdir -p "$(dirname "$IOS_KEY_PATH")"
  printf "%s" "${MAPS_API_KEY}" > "$IOS_KEY_PATH"
  echo "[CI] Wrote iOS API key to $IOS_KEY_PATH"

  mkdir -p "$(dirname "$IOS_SECRETS_PATH")"
  printf "MAPS_API_KEY=%s\n" "${MAPS_API_KEY}" > "$IOS_SECRETS_PATH"
  echo "[CI] Wrote iOS build setting to $IOS_SECRETS_PATH"
fi

echo "[CI] Key injection complete"
