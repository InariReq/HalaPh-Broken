#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if [ -d ios ]; then
  echo "==> CocoaPods: cleaning and installing in ios/" 
  pushd ios > /dev/null
  rm -rf Pods Podfile.lock
  if command -v pod >/dev/null 2>&1; then
    pod deintegrate || true
    pod cache clean --all || true
    pod repo update
    pod install --verbose
  else
    echo "CocoaPods not found in PATH. Please install CocoaPods (e.g. 'sudo gem install cocoapods') and re-run." >&2
    exit 1
  fi
  popd > /dev/null
else
  echo "ios/ directory not found, skipping pods." >&2
fi

echo "Done."
