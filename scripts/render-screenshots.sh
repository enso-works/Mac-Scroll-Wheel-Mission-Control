#!/bin/zsh
# Renders README screenshots of the settings window (docs/images/settings-*.png).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p build
sed "s/__VERSION__/$(cat VERSION)/g" Resources/Info.plist > build/Screenshot-Info.plist
SOURCES=(${(f)"$(ls Sources/ScrollWheelMissionControl/*.swift | grep -v '/App.swift$')"})
# Embedding Info.plist gives the renderer the real version string.
# Top-level code is only allowed in a file named main.swift.
cp scripts/render-screenshots.swift build/main.swift
swiftc -O -D SCREENSHOTS -o build/render-screenshots "${SOURCES[@]}" build/main.swift \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker build/Screenshot-Info.plist 2>&1 | grep -v warning || true
./build/render-screenshots
