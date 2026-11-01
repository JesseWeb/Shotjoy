# Releasing

Every user-visible change gets a new version and a new GitHub Release.

## Version rules

- Bug fix / copy change / visual polish: **patch** (`1.0.1` → `1.0.2`)
- New feature: **minor** (`1.0.x` → `1.1.0`)
- Breaking change: **major** (`1.x` → `2.0.0`)

`CFBundleVersion` is incremented automatically by the release script.

## One command

```sh
./scripts/release.sh 1.0.2
```

The script:

1. Requires a clean git working tree.
2. Bumps `CFBundleShortVersionString` and `CFBundleVersion` in
   `Support/Info.plist`.
3. Updates the `Shotjoy-x.y.z.dmg` examples in README/docs.
4. Builds an **ad-hoc signed universal** DMG (`arm64 x86_64`) so a personal
   Apple Development identity is never published.
5. Verifies the signature, both architectures, and the DMG.
6. Commits `Release vX.Y.Z`, creates and pushes the `vX.Y.Z` tag.
7. Creates or updates the GitHub Release and uploads the DMG.

## Prerequisites

```sh
brew install gh
```

`release.sh` needs a GitHub token with `repo` (and ideally `workflow`) access for
the account that owns `JesseWeb/Shotjoy`. It uses `GH_TOKEN` when set, otherwise
it reuses the credential git already stores in the macOS keychain, so on a
machine that can push to the repository no separate login step is required.

If neither is available, run `gh auth login` once.

## Release notes

`release.sh` starts from `--generate-notes`. To write real notes, pass a **plain
Markdown** file:

```sh
./scripts/set-release-notes.sh 1.0.5 docs/notes-1.0.5.md
```

Do not pass a JSON payload such as `{"body": "..."}`. `gh release edit
--notes-file` copies the file verbatim, so JSON ends up on the release page as
escaped text (`\uff08`, `\u622a`). `set-release-notes.sh` rejects JSON input and
verifies the stored body afterwards.

## If Actions is disabled

The repository contains `.github/workflows/release.yml`, which can build and
publish a DMG from a `v*` tag. If GitHub Actions is disabled for the account,
`release.sh` still publishes manually with `gh`; this is the current path.

## Signed / notarized builds

The release script deliberately uses ad-hoc signing. For a Developer ID +
notarized build, follow [`distribution.md`](distribution.md) and upload that
DMG instead.
