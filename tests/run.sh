#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Compile the app's real models and JSON persistence, including its actual theme.
# Keep the executable outside the synchronized iOS app target.
xcrun swiftc -swift-version 5 \
  GlassScale/Core/Model/*.swift \
  GlassScale/Design/AppTheme.swift \
  GlassScale/Core/Store/Persistence.swift \
  tests/main.swift \
  -o "$TEST_DIR/core-regressions"

TZ=Asia/Shanghai "$TEST_DIR/core-regressions"
TZ=America/Los_Angeles "$TEST_DIR/core-regressions"
