# Status

## Verified

- `swift test`: **23 tests, 0 failures** (geometry, annotations, stitching,
  shortcut model, file naming).
- `./scripts/make-app.sh release`: builds and signs `dist/Shotjoy.app`.
- `SHOTJOY_ARCHS="arm64 x86_64" ./scripts/make-dmg.sh release`: universal
  `dist/Shotjoy-1.0.0.dmg`, mounted and `codesign --verify --strict` passed.
- `--self-test`: renders an 800×600 PNG with rectangle, arrow, text and mosaic;
  top/bottom orientation and annotation placement verified visually.
- `--capture-test`: ScreenCaptureKit captured the display at **2880×1800 @2.0**,
  and a selected region rendered to **1600×1188** with an annotation.
- `--demo-overlay`: synthetic overlay renders the dimmed desktop, bright
  selection, handles, annotations, a live draft stroke, and the toolbar.
- `--ocr-test`: Vision recognized `Shotjoy 文字识别 Test 123`.
- `--analyze-test`: OCR result copied to the clipboard and shown in the floating
  result window.
- `--status` for the renamed bundle: `permission=true` (Screen Recording
  re-granted for the new bundle id), `hotkeyRegistered=true`, shortcut `⌃⌘A`,
  bundle id `dev.shotjoy.Shotjoy`, path `/Applications/Shotjoy.app`.
- After the rename, `⌃⌘A` opened the full-screen overlay on the unlocked
  screen; the new app bundle and status icon are live.
- `--capture-test` after the rename still captures **2880×1800 @2.0** and renders
  **1600×1188**; `--ocr-test` recognizes `Shotjoy 文字识别 Test 123`.

## Live end-to-end checks

With the screen unlocked and Screen Recording granted:

1. `⌃⌘A` opened the full-screen overlay with dimmed desktop, crosshair,
   magnifier, live colour/coordinates.
2. Dragging produced a bright selection with eight handles and the floating
   toolbar below it.
3. Selecting the **pen** and dragging showed the red stroke **while the mouse
   was still down**; releasing committed it.
4. Clicking the **text recognition** toolbar button closed the overlay, copied
   the recognized text to the clipboard, and opened the floating
   **Recognize Text** result window.
5. With the move/pointer tool active, dragging inside the selection moved the
   whole selection (and the toolbar followed it).
6. The colour palette showed all six swatches; clicking blue moved the white
   ring and checkmark to blue.
7. Clicking the AI face-masking button on a face-free selection showed the
   "No faces detected" toast instead of doing nothing.

## Still worth a manual pass

- Pin to desktop and its context menu.
- Scrolling capture with a long page.
- QR/barcode detection.
- AI face masking.
- Hotkey conflict with WeChat, if both are running.
