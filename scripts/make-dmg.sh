#!/bin/bash
#
# Build a drag-to-Applications disk image: dist/ShotDesk-<version>.dmg
#
# Usage: ./scripts/make-dmg.sh [debug|release]

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
./scripts/make-app.sh "$CONFIG"

APP="dist/ShotDesk.app"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
DMG="dist/ShotDesk-${VERSION}.dmg"

STAGE="$(mktemp -d)/ShotDesk"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/ShotDesk.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "ShotDesk" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

rm -rf "$(dirname "$STAGE")"

IDENTITY="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
if [[ -n "$IDENTITY" && "$IDENTITY" != "adhoc" ]]; then
    if codesign --force --sign "$IDENTITY" --timestamp "$DMG" 2>/dev/null; then
        echo "Signed $DMG with $IDENTITY"
    else
        echo "warning: could not sign the dmg; it will still open locally" >&2
    fi
fi

SIZE="$(du -h "$DMG" | cut -f1)"
echo "Built $DMG ($SIZE)"
echo
echo "Next: ./scripts/notarize.sh \"$DMG\"   (needs a Developer ID build)"
