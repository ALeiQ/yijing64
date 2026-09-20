#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="Yijing64.xcodeproj"
SCHEME="Yijing64"
BUNDLE_ID="com.liuzixiang.Yijing64"
SIM_UDID="${SIM_UDID:-928C09EA-3720-4D66-BA17-732A264FB76C}"
DEVICE_UDID="${DEVICE_UDID:-00008030-000804100CE8802E}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-T8TG4WAR43}"

echo "==> [1/2] 模拟器构建"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=$SIM_UDID" -derivedDataPath .build/dd build

echo "==> [1/2] 模拟器安装并启动"
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM_UDID" ".build/dd/Build/Products/Debug-iphonesimulator/Yijing64.app"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

echo "==> [2/2] 真机构建"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "id=$DEVICE_UDID" -derivedDataPath .build/device build \
  CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"

echo "==> [2/2] 真机安装并启动"
xcrun devicectl device install app --device "$DEVICE_UDID" \
  .build/device/Build/Products/Debug-iphoneos/Yijing64.app
xcrun devicectl device process terminate --device "$DEVICE_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun devicectl device process launch --device "$DEVICE_UDID" "$BUNDLE_ID"

echo "==> 完成：模拟器与真机均已同步"
