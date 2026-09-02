#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
TEST_DIRECTORY="$(mktemp -d)"
TEST_BINARY="$TEST_DIRECTORY/SlotClipboardRingTests"

trap 'rm -rf "$TEST_DIRECTORY"' EXIT

xcrun swiftc \
  -swift-version 5 \
  -O \
  -parse-as-library \
  -framework AppKit \
  "$PROJECT_DIR/Sources/ClipboardEntry.swift" \
  "$PROJECT_DIR/Sources/ClipboardRing.swift" \
  "$PROJECT_DIR/Tests/ClipboardRingTests.swift" \
  -o "$TEST_BINARY"

"$TEST_BINARY"
