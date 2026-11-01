# AGENTS.md

Instructions for coding agents (Claude Code, Codex, Cursor, Gemini CLI, …) asked
to build, install, or modify **Shotjoy（截趣）**.

Shotjoy is a fast, local-only macOS screenshot tool: region/window capture,
annotations, scrolling screenshots, pin-to-desktop, OCR/QR and AI face masking.

Shotjoy is a local-only macOS screenshot menu-bar app written in Swift
(built with Xcode, no third-party dependencies). Everything needed is in this repository.

---

## 1. What the user usually wants

> "Install Shotjoy on my Mac."

That means:

1. Build `dist/Shotjoy.app`.
2. Copy it to `/Applications/Shotjoy.app`.
3. Launch it.
4. Walk the user through Screen Recording permission.
5. Verify a real capture works (overlay appears, selection copies to clipboard).

Do not stop after the build. An installed app that cannot capture is not
finished work.

---

## 2. Preconditions (check, don't install)

```sh
sw_vers -productVersion          # must be >= 14.0
xcodebuild -version              # Xcode 15+; Command Line Tools alone are not enough
swift --version                  # Swift 5.9+
```

If Xcode is missing, ask the user to install it from the App Store and run
`sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`. Do not try to
install Xcode, Homebrew, or other toolchains yourself.

Pick a user-controlled working directory (e.g. `~/Developer/Shotjoy`). Ask
before writing outside it, apart from the `/Applications` copy.

---

## 3. Build

```sh
git clone https://github.com/JesseWeb/Shotjoy.git ~/Developer/Shotjoy
cd ~/Developer/Shotjoy
swift test                         # 23 core tests, no UI
./scripts/make-app.sh release      # -> dist/Shotjoy.app
./scripts/make-dmg.sh release      # optional -> dist/Shotjoy-1.0.4.dmg
```

`make-app.sh`:

- `swift build -c release --product Shotjoy`
- assembles `dist/Shotjoy.app` from the binary, `Support/Info.plist`, and
  `AppIcon.icns` generated from `Support/AppIcon.png` (or script-generated)
- signs with the building machine's identity (override with
  `SHOTJOY_SIGN_IDENTITY`); never hard-code a developer name or team ID

Never commit `dist/`, `.build/`, signed artifacts, certificates, or profiles.

---

## 4. Release a new version

Every user-visible change must bump the version and publish a GitHub Release:

```sh
./scripts/release.sh 1.0.2
```

This bumps `Support/Info.plist`, builds an ad-hoc universal DMG, commits
`Release vX.Y.Z`, tags and pushes it, and creates the GitHub Release with the
DMG. It reuses the GitHub credential git already stores, so no separate
`gh auth login` is needed on a machine that can push.

To write custom notes, pass plain Markdown (never a JSON `{"body": ...}` file):

```sh
./scripts/set-release-notes.sh 1.0.5 notes.md
```

See [`docs/releasing.md`](docs/releasing.md).

## 5. Install and launch

```sh
pkill -x Shotjoy 2>/dev/null || true
rm -rf /Applications/Shotjoy.app
cp -R dist/Shotjoy.app /Applications/
open /Applications/Shotjoy.app
pgrep -x Shotjoy
```

Keep the app at `/Applications` (a stable path matters for TCC). The app is
`LSUIElement`: no Dock icon; a viewfinder appears in the menu bar.

Agent checks that do not need the GUI:

```sh
open -a /Applications/Shotjoy.app --args --status
cat /tmp/shotjoy-status.txt           # permission / shortcut / bundle

open -a /Applications/Shotjoy.app --args --self-test
sips -g pixelWidth -g pixelHeight /tmp/shotjoy-render-test.png

open -a /Applications/Shotjoy.app --args --demo-overlay
# synthetic overlay + toolbar, no Screen Recording permission needed
```

---

## 6. Screen Recording permission

Shotjoy uses ScreenCaptureKit/CoreGraphics. macOS requires **System Settings →
Privacy & Security → Screen Recording**.

Steps for the user:

1. Press `⌃⌘A` (or click the menu-bar icon).
2. Shotjoy requests permission and opens the pane.
3. Switch **Shotjoy** on.
4. If capture still fails, quit and reopen Shotjoy, then press `⌃⌘A` again.

You may open the pane for the user:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

You cannot flip the TCC switch programmatically. Do not disable SIP, edit
`TCC.db`, or otherwise bypass the prompt.

### "The switch is on but it still asks"

This is expected for ad-hoc signatures: every rebuild changes the code identity.
Use **menu-bar icon → Fix Screen Recording Permission…** (it runs
`tccutil reset ScreenCapture dev.shotjoy.Shotjoy`), then grant again. A
Developer ID or Apple Development signature keeps the grant stable.

### Verifying a capture

1. Open TextEdit or any visible window.
2. Press `⌃⌘A`.
3. The screen dims and the toolbar appears. Drag a rectangle.
4. Click **Done** (or press Return). The selection is now on the clipboard.
5. Paste into TextEdit with `⌘V`.

If the shortcut does nothing:

- Another app may own `⌃⌘A`. Quit it, or change Shotjoy's shortcut in
  **Settings… → Record**.
- Check the menu-bar icon's menu item shows the expected shortcut.

---

## 7. First-run behaviour worth knowing

- **Hotkey conflict.** If another app owns `⌃⌘A`, registration fails and a
  warning appears. Do not kill other apps without asking; offer the menu bar or
  the shortcut recorder instead.
- **Screen locked.** The overlay cannot receive clicks while macOS is locked.
  Ask the user to unlock and test again. `--status` reports permission only,
  not lock state.
- **Scrolling capture** is heuristic. It works best with a steady trackpad
  scroll and content with enough texture. Very fast jumps or long blank areas
  can produce a seam.
- **AI features are local.** OCR/QR/face detection use Apple Vision. There is
  no cloud AI feature. The AI button is **face masking**, not an
  emoji/sticker tool; if no face is detected it shows a toast.
- **Pins are session-only.** Pinned images disappear when Shotjoy quits.
- **No history.** Only the last screenshot is kept in memory for the menu.

---

## 8. Rules for changing the project

- **Source only.** `dist/` and `.build/` are gitignored. Never commit built
  `.app`, `.icns`, `.dmg`, certificates, `.p12`, or provisioning profiles.
- **Original work.** Do not copy code, assets, icons, sounds, strings, or data
  formats from other screenshot apps. Behaviour may be reproduced from public
  APIs and observation; implementation must be original.
- **No network.** Keep the local-only promise: no analytics, telemetry,
  auto-update, account, or cloud sync.
- **Keep `ShotjoyCore` UI-free.** It has no AppKit dependency so its tests are
  fast and portable.
- **Don't require a signing identity.** Builds must work ad-hoc on a fresh Mac.
- **Keep docs in sync.** User-facing changes belong in `README.md`,
  `docs/ai-install.md`, and this file.
- **Respect the license.** AGPL-3.0; keep notices.

### Layout

```
Package.swift                     project manifest
Sources/ShotjoyCore/             geometry, annotations, stitching, hotkey model
Sources/Shotjoy/                 menu-bar app (AppKit + SwiftUI)
  AppDelegate.swift               lifecycle, capture, OCR/QR, permissions
  Services/                       capture, overlay, hotkey, Vision, status item
  Views/                          overlay, toolbar, settings, HUD, preview
  Windows/                        overlay/toolbar/pin/settings/preview panels
Tests/ShotjoyCoreTests/          core tests (23)
Support/Info.plist                LSUIElement, bundle id, minimum macOS 14
scripts/                          make-app, make-dmg, notarize, make-icon
docs/                             AI install and distribution
```
