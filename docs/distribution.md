# Distribution

Shotjoy is source-only in normal use. This page is for maintainers who ship a
DMG.

## Build

```sh
SHOTJOY_ARCHS="arm64 x86_64" ./scripts/make-dmg.sh release
```

The app is signed with the best identity on the build machine:

1. `SHOTJOY_SIGN_IDENTITY` (for example `Developer ID Application: Name (TEAM)`)
2. `Developer ID Application`
3. `Apple Development`
4. ad-hoc

A Developer ID build also gets the hardened runtime (`--options runtime`), which
notarization requires. The DMG is signed with the same authority.

## Notarize

Credentials, pick one:

```sh
# App-specific password
APPLE_ID=you@example.com \
APPLE_TEAM_ID=ABCDE12345 \
APPLE_APP_PASSWORD=abcd-efgh-ijkl-mnop \
./scripts/notarize.sh dist/Shotjoy-1.0.2.dmg
```

or an App Store Connect API key:

```sh
NOTARY_KEY_PATH=/path/AuthKey_XXXX.p8 \
NOTARY_KEY_ID=XXXX \
NOTARY_ISSUER=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
./scripts/notarize.sh dist/Shotjoy-1.0.2.dmg
```

The script checks that the app inside the DMG is Developer ID signed and has the
hardened runtime, submits with `notarytool`, staples, and runs `spctl`.

## Ad-hoc builds

Without a Developer ID, the DMG still works locally but Gatekeeper blocks a
plain double-click on another Mac. Tell users to right-click → **Open** →
**Open**. Screen Recording is bound to the code signature, so every ad-hoc
rebuild may need a fresh grant (menu-bar icon → **Fix Screen Recording
Permission…**).

## CI

`.github/workflows/macos-build.yml` compiles and tests only; it publishes
nothing. Add a release workflow if you have signing secrets, but never commit
them and never require the maintainer's certificate to build.
