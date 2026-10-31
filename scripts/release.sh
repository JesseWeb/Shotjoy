#!/bin/bash
#
# Cut a new Shotjoy release.
#
# Usage:
#   ./scripts/release.sh 1.0.1
#
# The script:
#   1. bumps CFBundleShortVersionString and CFBundleVersion
#   2. updates the example DMG names in README/docs
#   3. builds an ad-hoc universal DMG (no personal signing identity)
#   4. commits the version bump, tags vX.Y.Z, and pushes to GitHub
#   5. creates the GitHub Release and uploads the DMG (requires gh + auth)
#
# Every user-visible change should get a new patch version and a new release.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "usage: $0 <major.minor.patch>   e.g. ./scripts/release.sh 1.0.1" >&2
    exit 64
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "error: working tree is not clean; commit or stash changes first" >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI (gh) is required: brew install gh && gh auth login" >&2
    exit 1
fi

OLD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Support/Info.plist)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Support/Info.plist)"
NEW_BUILD=$((BUILD + 1))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Support/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" Support/Info.plist

python3 - "$OLD_VERSION" "$VERSION" <<'PY'
import pathlib, sys
old, new = sys.argv[1], sys.argv[2]
files = [
    "README.md", "README.zh-CN.md", "README.zh-TW.md",
    "README.ja.md", "README.fr.md", "README.es.md",
    "AGENTS.md", "docs/ai-install.md", "docs/distribution.md",
    "docs/releasing.md", "scripts/notarize.sh",
]
for name in files:
    path = pathlib.Path(name)
    if not path.exists():
        continue
    text = path.read_text()
    path.write_text(text.replace(f"Shotjoy-{old}.dmg", f"Shotjoy-{new}.dmg"))
PY

SHOTJOY_SIGN_IDENTITY=adhoc \
SHOTJOY_ARCHS="arm64 x86_64" \
    ./scripts/make-dmg.sh release

DMG="dist/Shotjoy-${VERSION}.dmg"
APP="dist/Shotjoy.app"

test -f "$DMG"
codesign --verify --strict --deep "$APP"
codesign -dv --verbose=2 "$APP" 2>&1 | grep -q "Signature=adhoc" || {
    echo "error: expected an ad-hoc signed release build" >&2
    exit 1
}
lipo -archs "$APP/Contents/MacOS/Shotjoy" | grep -q "arm64" || {
    echo "error: arm64 slice missing" >&2
    exit 1
}
lipo -archs "$APP/Contents/MacOS/Shotjoy" | grep -q "x86_64" || {
    echo "error: x86_64 slice missing" >&2
    exit 1
}

git add -A
git commit -m "Release v${VERSION}"
git tag -a "v${VERSION}" -m "Shotjoy ${VERSION}"

git -c credential.helper=osxkeychain push origin main
git -c credential.helper=osxkeychain push origin "v${VERSION}"

if gh release view "v${VERSION}" >/dev/null 2>&1; then
    gh release upload "v${VERSION}" "$DMG" --clobber
else
    gh release create "v${VERSION}" \
        --title "Shotjoy（截趣）${VERSION}" \
        --generate-notes \
        "$DMG"
fi

echo
echo "Released v${VERSION}: $DMG"
