# Status

## Verified

- `swift test`: **23 tests, 0 failures** (geometry, annotations, stitching,
  shortcut model, file naming).
- `./scripts/make-app.sh release`: builds and signs `dist/ShotDesk.app`.
- `SHOTDESK_ARCHS="arm64 x86_64" ./scripts/make-dmg.sh release`: universal
  `dist/ShotDesk-1.0.0.dmg`, mounted and `codesign --verify --strict` passed.
- `--self-test`: renders an 800×600 PNG with rectangle, arrow, text and mosaic;
  top/bottom orientation and annotation placement verified visually.
- `--capture-test` (run from a process that already has Screen Recording):
  ScreenCaptureKit captured the display at **2880×1800 @2.0**, and a selected
  region rendered to **1600×1188** with an annotation. This confirms the
  Retina sizing, crop, and final-render path.
- `--demo-overlay`: the synthetic overlay window renders the dimmed desktop,
  bright selection, handles, annotations, and the toolbar (captured per-window).
- `--status`: `hotkeyRegistered=true`, shortcut `⌃⌘A`, bundle id
  `dev.shotdesk.ShotDesk`, path `/Applications/ShotDesk.app`.

## Pending (needs an unlocked screen)

The Mac was locked (`CGSSessionScreenIsLocked=1`) during the final session, so
these need a human:

1. Grant **System Settings → Privacy & Security → Screen Recording** to ShotDesk.
2. Press `⌃⌘A` and drag a selection; confirm the toolbar appears and is clickable.
3. Press Return / click Done; paste into TextEdit.
4. Test pin, OCR/QR, AI mask, and one scrolling capture.

The app is installed at `/Applications/ShotDesk.app`; the DMG is in `dist/`.
