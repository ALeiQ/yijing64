#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="易经模拟器"
DEST="/Applications/$APP_NAME.app"
LAUNCH_SCRIPT="$ROOT/scripts/simulator-launch.sh"
ASSETS="$ROOT/Yijing64/Assets.xcassets/AppIcon.appiconset"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ICONSET="$WORK/AppIcon.iconset"
ICNS="$WORK/AppIcon.icns"
mkdir -p "$ICONSET"

cp "$ASSETS/AppIconMac-16.png"   "$ICONSET/icon_16x16.png"
cp "$ASSETS/AppIconMac-32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ASSETS/AppIconMac-32.png"   "$ICONSET/icon_32x32.png"
cp "$ASSETS/AppIconMac-64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ASSETS/AppIconMac-128.png"  "$ICONSET/icon_128x128.png"
cp "$ASSETS/AppIconMac-256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ASSETS/AppIconMac-256.png"  "$ICONSET/icon_256x256.png"
cp "$ASSETS/AppIconMac-512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ASSETS/AppIconMac-512.png"  "$ICONSET/icon_512x512.png"
cp "$ASSETS/AppIconMac-1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ICNS"

TMP_APP="$WORK/$APP_NAME.app"
cat > "$WORK/launcher.applescript" <<EOF
on run
	do shell script "nohup /bin/bash '$LAUNCH_SCRIPT' >/dev/null 2>&1 &"
end run
EOF
osacompile -o "$TMP_APP" "$WORK/launcher.applescript"

cp "$ICNS" "$TMP_APP/Contents/Resources/applet.icns"
codesign --force --deep --sign - "$TMP_APP" >/dev/null 2>&1

if [ -e "$DEST" ]; then
  rm -rf "$DEST" 2>/dev/null || sudo rm -rf "$DEST"
fi
if ! cp -R "$TMP_APP" /Applications/ 2>/dev/null; then
  echo "==> /Applications 无写权限，使用 sudo"
  sudo cp -R "$TMP_APP" /Applications/
fi

touch "$DEST"
echo "已安装：$DEST"
echo "首次使用可直接双击；若被 Gatekeeper 拦截，右键 → 打开 一次即可。"
