#!/usr/bin/env bash
set -euo pipefail

echo "Setting up Flutter development environment on macOS..."

# 1) Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Please install Homebrew first: https://brew.sh/"
  exit 1
fi

echo "Updating Homebrew..."
bash -lc "brew update"

# 2) Flutter SDK (via Homebrew Cask)
if ! command -v flutter >/dev/null 2>&1; then
  echo "Installing Flutter SDK via Homebrew..."
  brew install --cask flutter
else
  echo "Flutter already installed. Skipping."
fi

# 3) Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
else
  echo "Xcode Command Line Tools already installed."
fi

# 4) Android Studio (for Android development)
if ! command -v idea >/dev/null 2>&1 && ! command -v studio >/dev/null 2>&1; then
  echo "Installing Android Studio (for Android development)..."
  brew install --cask android-studio
else
  echo "Android Studio already installed."
fi

# 5) Java (for Android tooling, if needed)
if ! java -version 2>&1 | grep -q 'version'; then
  echo "Installing AdoptOpenJDK 21..."
  brew install --cask temurin
else
  echo "Java runtime found."
fi

# 6) Optional IDE (VS Code)
if ! command -v code >/dev/null 2>&1; then
  echo "Installing VS Code (optional)..."
  brew install --cask visual-studio-code
else
  echo "VS Code already installed."
fi

echo
echo "Setup complete. Run the following to verify your environment:"
echo "  flutter doctor"
echo "  flutter pub get"
