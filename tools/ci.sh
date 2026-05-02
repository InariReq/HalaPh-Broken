#!/usr/bin/env bash
set -euo pipefail

echo "[CI] Starting build and test pipeline..."

# Optional: run Firebase Emulators for end-to-end testing
USE_FIREBASE_EMULATORS="${USE_FIREBASE_EMULATORS:-false}"
EMULATORS_PID=0
if [ "${USE_FIREBASE_EMULATORS,,}" = "true" ]; then
  echo "[CI] Starting Firebase Emulators (Firestore/Auth/DB) for end-to-end tests..."
  firebase emulators:start --project halaph-d4eaa --only firestore,auth,database --host 127.0.0.1 > /tmp/firebase_emulators.log 2>&1 &
  EMULATORS_PID=$!
  echo "[CI] Emulators launched (PID $EMULATORS_PID). Waiting for startup..."
  sleep 20
fi

echo "[CI] iOS: Installing CocoaPods... (macOS only)"
if [ "$(uname)" = "Darwin" ]; then
  cd ios
  pod install --repo-update
  cd ..
else
  echo "[CI] Skipping CocoaPods install: non-macOS environment"
fi

echo "[CI] Running Flutter analysis..."
flutter analyze

echo "[CI] Running Flutter tests..."
flutter test

# Teardown emulators if started
if [ ${EMULATORS_PID} -ne 0 ]; then
  echo "[CI] Shutting down Firebase Emulators (PID ${EMULATORS_PID})..."
  kill ${EMULATORS_PID} || true
  wait ${EMULATORS_PID} 2>/dev/null || true
fi

echo "[CI] Building Android APK..."
flutter build apk --debug

echo "[CI] All steps completed."
