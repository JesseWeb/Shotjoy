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
gh auth login
```

`gh` needs `repo` and `workflow` access for the account that owns
`JesseWeb/Shotjoy`.

## If Actions is disabled

The repository contains `.github/workflows/release.yml`, which can build and
publish a DMG from a `v*` tag. If GitHub Actions is disabled for the account,
`release.sh` still publishes manually with `gh`; this is the current path.

## Signed / notarized builds

The release script deliberately uses ad-hoc signing. For a Developer ID +
notarized build, follow [`distribution.md`](distribution.md) and upload that
DMG instead.
