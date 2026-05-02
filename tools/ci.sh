#!/usr/bin/env bash
set -euo pipefail

echo "[CI] Starting build and test pipeline..."

echo "[CI] iOS: Installing CocoaPods..."
cd ios
pod install --repo-update
cd ..

echo "[CI] Running Flutter analysis..."
flutter analyze

echo "[CI] Running Flutter tests..."
flutter test

echo "[CI] Building Android APK..."
flutter build apk --debug

echo "[CI] All steps completed."
