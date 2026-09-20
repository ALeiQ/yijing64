#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="Yijing64.xcodeproj"
SCHEME="Yijing64Mac"
DERIVED=".build/mac"
APP="$DERIVED/Build/Products/Debug/Yijing64.app"
BUNDLE_ID="com.liuzixiang.Yijing64Mac"

echo "==> 构建 macOS App"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=macOS" -derivedDataPath "$DERIVED" build

echo "==> 启动 macOS App"
osascript -e "quit app id \"$BUNDLE_ID\"" 2>/dev/null || true
open "$APP"

echo "==> 完成：$APP"
