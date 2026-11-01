#!/bin/bash
#
# Set the body of a published release from a plain Markdown file.
#
# Usage:
#   ./scripts/set-release-notes.sh 1.0.5 docs/notes-1.0.5.md
#
# Why this exists: `gh release edit --notes-file` copies the file verbatim. If
# you hand it a JSON payload such as {"body": "..."} the release page shows the
# escaped JSON instead of rendered Markdown. This script rejects JSON input and
# checks the stored body afterwards.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-}"
NOTES="${2:-}"

if [[ -z "$VERSION" || -z "$NOTES" ]]; then
    echo "usage: $0 <major.minor.patch> <notes.md>" >&2
    exit 64
fi

if [[ ! -f "$NOTES" ]]; then
    echo "error: $NOTES not found" >&2
    exit 1
fi

if head -c 200 "$NOTES" | tr -d '\n' | grep -q '^{[[:space:]]*"body"'; then
    echo "error: $NOTES looks like a JSON payload, not Markdown" >&2
    echo "hint: pass the Markdown itself, e.g. a file starting with '# Shotjoy'" >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "error: GitHub CLI (gh) is required: brew install gh" >&2
    exit 1
fi

# Same credential fallback as release.sh: no separate `gh auth login` needed on
# a machine that can already push to the repository.
if [[ -z "${GH_TOKEN:-}" && -z "${GITHUB_TOKEN:-}" ]]; then
    stored="$(printf 'protocol=https\nhost=github.com\n\n' | git credential-osxkeychain get 2>/dev/null || true)"
    stored_token="$(printf '%s\n' "$stored" | sed -n 's/^password=//p' | head -1)"
    if [[ -n "$stored_token" ]]; then
        export GH_TOKEN="$stored_token"
    fi
fi

gh release edit "v${VERSION}" -R JesseWeb/Shotjoy --notes-file "$NOTES" >/dev/null

BODY="$(gh api "repos/JesseWeb/Shotjoy/releases/tags/v${VERSION}" --jq '.body')"
case "$BODY" in
    '{"body"'*)
        echo "error: release v${VERSION} body is still JSON-wrapped" >&2
        exit 1
        ;;
esac

echo "Notes updated for v${VERSION} (${#BODY} characters of Markdown)"
