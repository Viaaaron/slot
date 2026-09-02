#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Slot.app"
BUILD_ARCH="$(uname -m)"
SIGNING_IDENTITY="${SLOT_SIGNING_IDENTITY:--}"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

xcrun swiftc \
  -swift-version 5 \
  -O \
  -whole-module-optimization \
  -parse-as-library \
  -target "$BUILD_ARCH-apple-macos13.0" \
  -framework AppKit \
  -framework ApplicationServices \
  "$PROJECT_DIR"/Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/Slot"

cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --timestamp=none --sign "$SIGNING_IDENTITY" "$APP_DIR"
echo "$APP_DIR"
