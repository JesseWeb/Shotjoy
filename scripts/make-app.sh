#!/bin/bash
#
# Build Shotjoy.app into dist/.
#
# Usage: ./scripts/make-app.sh [debug|release]
#
# Signing identity, in order:
#   1. $SHOTJOY_SIGN_IDENTITY
#   2. "Developer ID Application" (distribution; enables notarization)
#   3. "Apple Development" (stable local identity; keeps the TCC grant)
#   4. ad-hoc (no identity on the machine)

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"

ARCH_ARGS=""
if [[ -n "${SHOTJOY_ARCHS:-}" ]]; then
    for arch in $SHOTJOY_ARCHS; do
        ARCH_ARGS="$ARCH_ARGS --arch $arch"
    done
fi

swift build -c "$CONFIG" $ARCH_ARGS --product Shotjoy

BIN_DIR="$(swift build -c "$CONFIG" $ARCH_ARGS --show-bin-path)"
APP="dist/Shotjoy.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Shotjoy" "$APP/Contents/MacOS/Shotjoy"
cp Support/Info.plist "$APP/Contents/Info.plist"
for lproj in Support/*.lproj; do
    [[ -d "$lproj" ]] && cp -R "$lproj" "$APP/Contents/Resources/"
done

if [[ ! -f Support/AppIcon.png ]]; then
    swift scripts/make-icon.swift
fi

ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
while IFS=: read -r pixels name; do
    sips -z "$pixels" "$pixels" Support/AppIcon.png \
        --out "$ICONSET_DIR/icon_${name}.png" >/dev/null
done <<'SIZES'
16:16x16
32:16x16@2x
32:32x32
64:32x32@2x
128:128x128
256:128x128@2x
256:256x256
512:256x256@2x
512:512x512
1024:512x512@2x
SIZES
iconutil -c icns "$ICONSET_DIR" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$(dirname "$ICONSET_DIR")"

pick_identity() {
    local pattern="$1"
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n "s/.*\"\\(${pattern}:.*\\)\"/\\1/p" \
        | head -1
}

SIGN_ID="${SHOTJOY_SIGN_IDENTITY:-}"
if [[ "$SIGN_ID" == "adhoc" || "$SIGN_ID" == "-" ]]; then
    SIGN_ID=""
    FORCE_ADHOC=1
fi
if [[ -z "$SIGN_ID" && "${FORCE_ADHOC:-0}" != "1" ]]; then
    SIGN_ID="$(pick_identity 'Developer ID Application')"
fi
if [[ -z "$SIGN_ID" && "${FORCE_ADHOC:-0}" != "1" ]]; then
    SIGN_ID="$(pick_identity 'Apple Development')"
fi

if [[ -n "$SIGN_ID" ]]; then
    SIGN_ARGS=(--force --sign "$SIGN_ID")
    if [[ "$SIGN_ID" == Developer\ ID\ Application:* ]]; then
        SIGN_ARGS+=(--options runtime --timestamp)
    fi
    if ! codesign "${SIGN_ARGS[@]}" "$APP"; then
        echo "warning: signing with $SIGN_ID failed; falling back to ad-hoc" >&2
        codesign --force --sign - "$APP" >/dev/null 2>&1 || true
        SIGN_ID=""
    fi
else
    codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/Shotjoy" 2>/dev/null || echo "single arch"))"
if [[ -n "$SIGN_ID" ]]; then
    echo "Signed with $SIGN_ID"
else
    echo "Signed ad-hoc (no code signing identity on this machine)"
fi
echo "Run it with: open \"$APP\""
