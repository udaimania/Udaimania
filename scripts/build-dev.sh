#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Install Xcode in /Applications and complete its first launch before building." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  set -- build
fi

exec /usr/bin/xcodebuild \
  -project "$PROJECT_ROOT/macos/Udaimania.xcodeproj" \
  -scheme "Udaimania" \
  -configuration Development \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$PROJECT_ROOT/build/DerivedData/Udaimania" \
  "$@"
