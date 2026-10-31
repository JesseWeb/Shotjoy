#!/bin/bash
#
# Notarize and staple a Shotjoy disk image.
#
# Usage:
#   ./scripts/notarize.sh dist/Shotjoy-1.0.0.dmg
#
# Credentials, pick one:
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER

set -euo pipefail

DMG="${1:-}"
if [[ -z "$DMG" || ! -f "$DMG" ]]; then
    echo "usage: $0 <path/to/Shotjoy-x.y.z.dmg>" >&2
    exit 64
fi

MOUNT_POINT="$(mktemp -d)/mnt"
hdiutil attach "$DMG" -nobrowse -readonly -mountpoint "$MOUNT_POINT" >/dev/null
APP_PATH="$MOUNT_POINT/Shotjoy.app"

if [[ ! -d "$APP_PATH" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
    echo "error: $DMG does not contain Shotjoy.app" >&2
    exit 1
fi

AUTHORITY="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
HARDENED="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -c "flags=0x10000(runtime)" || true)"
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true

if [[ "$AUTHORITY" != Developer\ ID\ Application:* ]]; then
    cat >&2 <<EOF
error: the app is signed with "${AUTHORITY:-no identity}".
Notarization needs a "Developer ID Application" certificate.

Install one (Apple Developer Program), then rebuild:
  SHOTJOY_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \\
    ./scripts/make-dmg.sh release
EOF
    exit 1
fi

if [[ "$HARDENED" == "0" ]]; then
    echo "error: the hardened runtime flag is missing; rebuild so codesign adds --options runtime" >&2
    exit 1
fi

if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER:-}" ]]; then
    xcrun notarytool submit "$DMG" \
        --key "$NOTARY_KEY_PATH" \
        --key-id "$NOTARY_KEY_ID" \
        --issuer "$NOTARY_ISSUER" \
        --wait
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    xcrun notarytool submit "$DMG" \
        --apple-id "$APPLE_ID" \
        --team-id "$APPLE_TEAM_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --wait
else
    cat >&2 <<'EOF'
error: no notarization credentials found.

Set either:
  APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD
or:
  NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER
EOF
    exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo
echo "Notarized and stapled: $DMG"
