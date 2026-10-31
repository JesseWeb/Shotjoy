# How WeChat implements screenshots (and how ShotDesk mirrors it)

This note records the static evidence used to design ShotDesk. It is a
**clean-room** study: no WeChat code, resources, icons, or data formats were
copied.

## Target

| Field | Value |
|---|---|
| App | WeChat / 微信 for macOS 4.1.5 (build 31960) |
| Path | `/Applications/WeChat.app/Contents/MacOS/WeChat` |
| Format | Universal Mach-O, analysed slice `arm64` |
| Universal SHA-256 | `20f355ca7269a51fbc29e4b50ec4e74bdcac53f47e93dbc49245231f4f202b6d` |
| arm64 slice SHA-256 | `60172f477e4871d2f4b56b63b54f6f6db2f8c4af958de413dd8f19962d781499` |
| Host | macOS 26.5.2 (25F84), Apple Silicon |

Tools used:

- REA `open_binary`: confirmed the universal Mach-O and arm64 slice identity.
- `nm -u`, `otool -ov`, `strings`, `xcrun dyld_info`, and Mach-O symbol/data
  inspection for imported APIs, Objective-C metadata, C++ class names, UI
  strings, and preference keys.

**Coverage limitation.** A deep decompiler provider (Ghidra/Hopper/IDA/Kuna)
was not configured on this machine, so the evidence below is static
listing/string/API evidence, not decompiled method bodies. Anything marked
**inferred** is a design inference, not an observed implementation.

## 1. The feature is called "weshot"

The binary contains a self-contained screenshot subsystem written in C++ with
an Objective-C++ bridge:

```
weshot::ScreenShoter
weshot::LongScreenShoter
weshot::WeShot
weshot::WeShotEditor
weshot::WeShotEditorSubmenu
weshot::WeShotLongScreenshot
weshot::GrabWorker
weshot::SpliceWorker
weshot::OpenCVWorker
weshot::SizeSelect
weshot::ButtonGroup
weshot::ColorPanel
weshot::CoverAnimationWidget
weshot::AiMosaicButton
weshot::graphics::window_filter_t
mmui::ScreenshotView
mmui::ScreenShotClientService
mmui::ScreenShotPinWindow
```

There are also source-file strings:

```
screenshoter.cc
long_shot_test.cc        (fragmented in the string table as long_shot_test.c...)
config.json
```

and test/telemetry strings:

```
activate weshot
aimosaic_enter / aimosaic_leave
grab_assist / maintain_cur / get_offset / opencv_t
```

This is strong evidence for a layered design: a capture controller
(`ScreenShoter`), a long-screenshot controller (`LongScreenShoter`) with a frame
grabber (`GrabWorker`), a splicer (`SpliceWorker`), and an OpenCV helper
(`OpenCVWorker`). The UI is a `ScreenshotView` with a `ShotSelection` state
machine (see §4).

## 2. Global shortcut

The preferences keys are in one string pool:

```
showOrHideMainWindowShortcut
screenshotShortcut
lockScreenShortcut
modifierFlags
keyCode
```

`screenshotShortcut` is referenced by a `__cfstring` object at
`0x1086A2480` (dyld fixup to `0x108059980`). The value is stored as
`modifierFlags` + `keyCode`, i.e. an `NSEvent`-style shortcut record. The
default the user observes is **Control-Command-A** (`⌃⌘A`).

The app imports Carbon's `RegisterEventHotKey` and `UnregisterEventHotKey`, and
CoreGraphics' `CGEventCreateMouseEvent` / `CGEventPost`. This is the classic
global-hotkey combination that does **not** require Accessibility permission.

ShotDesk: `HotKeyManager` uses the same Carbon API and stores
`keyCode`/`modifiers`; the default is `⌃⌘A`, changeable with a recorder.

## 3. Capture APIs

WeChat imports all of the following (selected):

```
CGPreflightScreenCaptureAccess
CGDisplayCreateImage
CGDisplayCreateImageForRect
CGWindowListCreateImage
CGWindowListCreateImageFromArray
CGWindowListCopyWindowInfo
CGWindowListCreateDescriptionFromArray
SCScreenshotManager
SCShareableContent
SCStream
SCStreamConfiguration
CGImageCreateWithImageInRect
CGImageDestinationCreateWithData
CGImageDestinationAddImage
CGImageDestinationFinalize
NSPasteboard
CVDisplayLink*
CGDisplayStream*
IOSurface*
```

Interpretation:

- **Permission preflight**: `CGPreflightScreenCaptureAccess` before capture,
  then the Screen Recording pane
  (`x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`).
- **Legacy path**: `CGDisplayCreateImage` / `CGDisplayCreateImageForRect` for a
  display, `CGWindowListCreateImage` / `FromArray` for windows.
- **Modern path**: `SCScreenshotManager` + `SCShareableContent` (macOS 14+).
  The presence of both indicates a fallback strategy.
- **Window picking**: `CGWindowListCopyWindowInfo` gives the front-to-back
  window list, bounds, layer, owner PID, and alpha — exactly what a hover-to-
  highlight window picker needs.
- **Cropping/scaling**: `CGImageCreateWithImageInRect` for the selection.
- **Saving**: ImageIO `CGImageDestination*`.
- **Clipboard**: `NSPasteboard` (TIFF/PNG).
- **Long screenshot**: `CGDisplayStream` + `IOSurface` + `CVDisplayLink` are
  imported; these are plausible for continuous frame grabbing while the user
  scrolls.

ShotDesk: `ScreenCaptureService` prefers ScreenCaptureKit on macOS 14+, falls
back to `CGDisplayCreateImage`; `WindowLocator` uses
`CGWindowListCopyWindowInfo`; `ImageExporter` uses ImageIO and NSPasteboard.

## 4. The selection state machine

Strings in `__data` around `0x1086cdc80` describe the UI model:

```
ShotSelection
ShotSelectionStatus
captured
moved
resized
locked
statusChanged
drawSelected
showRegion
start
status
ScreenshotView
ScreenshotWillStart
ScreenshotDidFinish
signalUpdate
Captured
```

This is consistent with a selection object that emits `statusChanged` as it
moves between `start → captured → moved/resized → locked`, and a
`ScreenshotWillStart` / `ScreenshotDidFinish` pair around the overlay lifetime.
`showRegion` is the bright (un-dimmed) selection area; `drawSelected` paints it.

ShotDesk: `SelectionGeometry` implements normalise/move/resize/clamp and eight
handles; `CaptureSession` implements the start → drag → captured → move/resize →
finish state machine and emits equivalent redraw/update events.

## 5. The editor toolbar

The localized string pool contains the complete toolbar vocabulary. English
strings are at `0x1087892c1`–`0x1087894c1`:

```
Color
Crop
Photo Editor
Quit
Press Ctrl+C to copy color value
Photo too large. Unable to edit.
Scrolling screenshot
Screenshot interrupted. Return to the interruption point to continue scrolling.
Maximum length reached. Unable to continue screenshot.
Scroll the page to capture more content
Rectangle Tool
Restore
Add to Favorites
AI masking
Arrow
Ask AI / Ask AI … Powered by …
Done
Edit
Ellipse Tool
Sticker
Send to Chat
Mosaic
Brush
Pin to Desktop
QR Code
Save
Text
Undo (Ctrl+Z)
```

Chinese equivalents are at `0x11b0d3a0`–`0x11b0d58e`:

```
色值 / 裁剪 / 图片编辑 / 退出 / 按 Ctrl+C 复制色值
滚动截图 / 截图中断，返回中断位置继续滚动
已达最大长度，无法继续截图 / 滚动页面截取更多内容
坐标 / 矩形 / 还原 / 收藏 / 一键打码 / 箭头
问 AI / 问 AI｜由元宝提供 / 完成 / 编辑 / 椭圆 / 表情 / 转发
马赛克 / 画笔 / 置顶在桌面 / 二维码 / 保存图片 / 文字 / 撤销
```

The icon names in the binary confirm the toolbar artwork:

```
/icons/blue.svg  /icons/yellow.svg  /icons/line.svg
/icons/circle.svg  /icons/pencil.svg  /icons/mosaic.svg
/icons/qr_code.*  /icons/pushpin.*  /icons/xmark.svg
```

So the editor has: rectangle, ellipse, arrow, brush, mosaic, text, undo,
restore, colour picker/copy, AI masking, QR, pin, save, done, and a scrolling
screenshot entry. "Ask AI" is a Tencent Yuanbao integration, not a local
feature.

ShotDesk: the toolbar implements rectangle, ellipse, arrow, brush, mosaic,
text, colour palette, AI face masking, OCR/QR, scrolling capture, undo, pin,
save, cancel, done. The cloud "Ask AI", sticker, and "send to chat" are not
reproduced because they depend on WeChat's services.

## 6. Window hiding and multi-display behaviour

Settings strings:

```
Hide window screenshot
Keep current window when clicking the screenshot button
Keep window screenshot
Default
Press Shortcut
Device settings restrict screenshots for this app...
```

The default is to hide WeChat's own main window while capturing; the option can
keep it. The code imports `CGWindowListCopyWindowInfo` and per-display capture
APIs, so the overlay is built per display and a window-picker can exclude the
app's own PID.

ShotDesk: captures every display at native scale, creates one overlay window per
`NSScreen`, excludes its own windows by capturing before the overlay is shown,
and highlights the topmost foreign window under the cursor.

## 7. Long / scrolling screenshot

Evidence:

```
LongScreenShoter, GrabWorker, SpliceWorker, OpenCVWorker
long_shot_test, config.json, grab_assist, maintain_cur, get_offset, opencv_t
Scrolling screenshot
Screenshot interrupted. Return to the interruption point to continue scrolling.
Maximum length reached. Unable to continue screenshot.
Scroll the page to capture more content
```

This is a capture-loop architecture:

1. Grab frames of the selected region while the user scrolls.
2. Maintain the current offset / assist state.
3. Splice frames by finding the vertical overlap.
4. Use OpenCV for image matching / stitching; enforce a maximum length; allow
   resuming at the interruption point.

ShotDesk: `ScrollingCaptureController` grabs frames with
`CGDisplayCreateImageForRect`, `FrameStitcher` computes row-signature overlaps
(no OpenCV dependency), and the app splices the full-resolution frames and
enforces a 30,000-pixel / 120 M-pixel limit. The algorithm is a clean-room
approximation, not a copy of WeChat's OpenCV pipeline.

## 8. Pinning, colour sampling, QR and AI masking

Evidence:

```
mmui::ScreenShotPinWindow
ScreenShotPinWindow
Pin to Desktop / 置顶在桌面
Color / 色值 / 按 Ctrl+C 复制色值 / 按 ⌘+C 复制色值
QR Code / 二维码 / 识别图中二维码
AI masking / 一键打码 / AiMosaicButton
aimosaic_enter / aimosaic_leave
```

So the pin is a separate always-on-top window (`ScreenShotPinWindow`), the
magnifier exposes a colour value that can be copied with Ctrl/Cmd-C, QR
recognition is built into the editor, and "AI masking" has dedicated UI and
telemetry.

ShotDesk: `PinWindowController` (floating non-activating panel), magnifier HUD
with hex/coordinate readout, Apple Vision barcode detection, and Vision face
detection feeding mosaic annotations. No cloud AI.

## 9. What ShotDesk deliberately does differently

| WeChat | ShotDesk |
|---|---|
| C++ `weshot` + Qt/`mmui` editor | AppKit/SwiftUI, SwiftPM |
| OpenCV stitch worker | pure Swift row-signature stitch |
| Tencent Yuanbao "Ask AI" | not included (local-only promise) |
| WeChat account/chat integration | none |
| Proprietary icons and assets | SF Symbols + generated app icon |
| Integrated into WeChat | standalone menu-bar app |

## 10. Confidence summary

| Claim | Confidence | Basis |
|---|---|---|
| `weshot` is the screenshot subsystem | observed | class/source strings |
| `⌃⌘A` is stored as keyCode+modifierFlags | observed | preference keys + user-visible default |
| Global hotkey uses Carbon | observed | imported `RegisterEventHotKey` |
| Capture uses CGDisplay/CGWindow + ScreenCaptureKit | observed | imported symbols |
| Window hover/selection uses window list | inferred | imported `CGWindowListCopyWindowInfo` + UI strings |
| Long screenshot uses grab/splice/OpenCV workers | observed (components) / inferred (flow) | class names + test strings |
| Toolbar tool set | observed | localized strings + icon paths |
| Pin is a separate window | observed | `ScreenShotPinWindow` symbol |
| Exact method bodies, thread model, limits | unknown | no decompiler available |
