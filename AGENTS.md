# AGENTS.md

Instructions for coding agents (Claude Code, Codex, Cursor, Gemini CLI, …) asked
to build, install, or modify **ShotDesk**.

ShotDesk is a local-only macOS screenshot menu-bar app written in Swift
(SwiftPM, no third-party dependencies). Everything needed is in this repository.

---

## 1. What the user usually wants

> "Install ShotDesk on my Mac."

That means:

1. Build `dist/ShotDesk.app`.
2. Copy it to `/Applications/ShotDesk.app`.
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

Pick a user-controlled working directory (e.g. `~/Developer/ShotDesk`). Ask
before writing outside it, apart from the `/Applications` copy.

---

## 3. Build

```sh
git clone <this repository> ~/Developer/ShotDesk
cd ~/Developer/ShotDesk
swift test                         # 23 core tests, no UI
./scripts/make-app.sh release      # -> dist/ShotDesk.app
./scripts/make-dmg.sh release      # optional -> dist/ShotDesk-1.0.0.dmg
```

`make-app.sh`:

- `swift build -c release --product ShotDesk`
- assembles `dist/ShotDesk.app` from the binary, `Support/Info.plist`, and
  `AppIcon.icns` generated from `Support/AppIcon.png` (or script-generated)
- signs with the building machine's identity (override with
  `SHOTDESK_SIGN_IDENTITY`); never hard-code a developer name or team ID

Never commit `dist/`, `.build/`, signed artifacts, certificates, or profiles.

---

## 4. Install and launch

```sh
pkill -x ShotDesk 2>/dev/null || true
rm -rf /Applications/ShotDesk.app
cp -R dist/ShotDesk.app /Applications/
open /Applications/ShotDesk.app
pgrep -x ShotDesk
```

Keep the app at `/Applications` (a stable path matters for TCC). The app is
`LSUIElement`: no Dock icon; a viewfinder appears in the menu bar.

Agent checks that do not need the GUI:

```sh
open -a /Applications/ShotDesk.app --args --status
cat /tmp/shotdesk-status.txt           # permission / shortcut / bundle

open -a /Applications/ShotDesk.app --args --self-test
sips -g pixelWidth -g pixelHeight /tmp/shotdesk-render-test.png

open -a /Applications/ShotDesk.app --args --demo-overlay
# synthetic overlay + toolbar, no Screen Recording permission needed
```

---

## 5. Screen Recording permission

ShotDesk uses ScreenCaptureKit/CoreGraphics. macOS requires **System Settings →
Privacy & Security → Screen Recording**.

Steps for the user:

1. Press `⌃⌘A` (or click the menu-bar icon).
2. ShotDesk requests permission and opens the pane.
3. Switch **ShotDesk** on.
4. If capture still fails, quit and reopen ShotDesk, then press `⌃⌘A` again.

You may open the pane for the user:

```sh
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

You cannot flip the TCC switch programmatically. Do not disable SIP, edit
`TCC.db`, or otherwise bypass the prompt.

### "The switch is on but it still asks"

This is expected for ad-hoc signatures: every rebuild changes the code identity.
Use **menu-bar icon → Fix Screen Recording Permission…** (it runs
`tccutil reset ScreenCapture dev.shotdesk.ShotDesk`), then grant again. A
Developer ID or Apple Development signature keeps the grant stable.

### Verifying a capture

1. Open TextEdit or any visible window.
2. Press `⌃⌘A`.
3. The screen dims and the toolbar appears. Drag a rectangle.
4. Click **Done** (or press Return). The selection is now on the clipboard.
5. Paste into TextEdit with `⌘V`.

If the shortcut does nothing:

- WeChat also owns `⌃⌘A`. Quit WeChat, or change ShotDesk's shortcut in
  **Settings… → Record**.
- Check the menu-bar icon's menu item shows the expected shortcut.

---

## 6. First-run behaviour worth knowing

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
  no "Ask AI" cloud feature; WeChat's "问 AI" uses Tencent Yuanbao and is not
  reproduced.
- **Pins are session-only.** Pinned images disappear when ShotDesk quits.
- **No history.** Only the last screenshot is kept in memory for the menu.

---

## 7. Rules for changing the project

- **Source only.** `dist/` and `.build/` are gitignored. Never commit built
  `.app`, `.icns`, `.dmg`, certificates, `.p12`, or provisioning profiles.
- **Clean room.** Do not copy code, assets, icons, sounds, strings, or data
  formats from WeChat or other screenshot apps. Behaviour may be reproduced from
  public APIs and observation; implementation must be original.
- **No network.** Keep the local-only promise: no analytics, telemetry,
  auto-update, account, or cloud sync.
- **Keep `ShotDeskCore` UI-free.** It has no AppKit dependency so its tests are
  fast and portable.
- **Don't require a signing identity.** Builds must work ad-hoc on a fresh Mac.
- **Keep docs in sync.** User-facing changes belong in `README.md`,
  `docs/ai-install.md`, and this file.
- **Respect the license.** AGPL-3.0; keep notices.

### Layout

```
Package.swift                     SwiftPM manifest
Sources/ShotDeskCore/             geometry, annotations, stitching, hotkey model
Sources/ShotDesk/                 menu-bar app (AppKit + SwiftUI)
  AppDelegate.swift               lifecycle, capture, OCR/QR, permissions
  Services/                       capture, overlay, hotkey, Vision, status item
  Views/                          overlay, toolbar, settings, HUD, preview
  Windows/                        overlay/toolbar/pin/settings/preview panels
Tests/ShotDeskCoreTests/          core tests (23)
Support/Info.plist                LSUIElement, bundle id, minimum macOS 14
scripts/                          make-app, make-dmg, notarize, make-icon
docs/                             AI install, distribution, reverse engineering
```
