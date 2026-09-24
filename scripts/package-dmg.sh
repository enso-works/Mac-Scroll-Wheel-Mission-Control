#!/bin/zsh
# Packages build/*.app into a drag-to-Applications DMG and a zip in dist/.
# Writes both a versioned file and a stable-named copy for "latest" download links.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(cat VERSION)}"
APP="build/Scroll Wheel Mission Control.app"
STAGING="build/dmg"
NAME="ScrollWheelMissionControl"

rm -rf "$STAGING" dist
mkdir -p "$STAGING" dist
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Scroll Wheel Mission Control" -srcfolder "$STAGING" \
  -fs HFS+ -format UDZO -ov "dist/$NAME-$VERSION.dmg" >/dev/null
cp "dist/$NAME-$VERSION.dmg" "dist/$NAME.dmg"
ditto -c -k --keepParent "$APP" "dist/$NAME-$VERSION.zip"

(cd dist && shasum -a 256 *.dmg *.zip > SHA256SUMS.txt)
ls -lh dist
