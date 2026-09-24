#!/bin/zsh
# Builds a universal (Apple Silicon + Intel) app bundle into build/.
# Env: VERSION (defaults to ./VERSION), SIGN_IDENTITY (defaults to ad-hoc "-").
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/Scroll Wheel Mission Control.app"
ICONSET="build/AppIcon.iconset"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"
cp "$BIN_DIR/ScrollWheelMissionControl" "$APP/Contents/MacOS/"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon-1024.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
echo "Built $APP ($VERSION, signed with: $SIGN_IDENTITY)"
