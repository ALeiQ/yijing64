#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_UDID="${SIM_UDID:-AEA49BA7-D3EB-4EDC-9497-546D596E1FDE}"
BUNDLE_ID="com.liuzixiang.Yijing64"
PROJECT="Yijing64.xcodeproj"
SCHEME="Yijing64"
APP="$REPO/.build/dd/Build/Products/Debug-iphonesimulator/Yijing64.app"
LOG="$REPO/.build/sim-launcher.log"

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

mkdir -p "$REPO/.build"
exec >>"$LOG" 2>&1
echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="

cd "$REPO"

FORCE_BUILD=0
[ "${1:-}" = "--build" ] && FORCE_BUILD=1

if [ "$FORCE_BUILD" = "1" ] || [ ! -d "$APP" ]; then
  echo "==> 构建模拟器版（缺失或强制）"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -destination "id=$SIM_UDID" -derivedDataPath .build/dd build
fi

echo "==> 启动模拟器并等待就绪"
xcrun simctl bootstatus "$SIM_UDID" -b
open -a Simulator

echo "==> 安装并打开 App"
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIM_UDID" "$APP"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

echo "==> 完成"
