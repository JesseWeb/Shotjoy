# Install Shotjoy with an AI agent

Shotjoy ships a signed DMG, but building from source is still the most reliable
route: the app then carries **your** code signature, so the Screen Recording
grant stays stable across rebuilds. This page is the prompt that hands that job
to a coding agent.

Prefer to do it by hand? See **Install → Build it yourself** in the
[README](../README.md#install).

## What you need

- macOS 14 or newer with Xcode 15+ installed (`xcodebuild -version` works)
- A coding agent that can run shell commands: Claude Code, Codex, Cursor,
  Gemini CLI, OpenCode, or similar

## Copy-paste prompt

### 简体中文

> 帮我在这台 Mac 上安装 Shotjoy：
> 1. 把仓库克隆到 ~/Developer/Shotjoy
> 2. 阅读仓库里的 AGENTS.md，按它执行 `swift test` 和 `./scripts/make-app.sh release`
> 3. 把 `dist/Shotjoy.app` 安装到 /Applications 并启动
> 4. 引导我在「系统设置 → 隐私与安全性 → 屏幕录制」中授权，然后实际按 ⌃⌘A 截图并粘贴验证
> 5. 如果其他 App 占用了 ⌃⌘A，帮我在 Shotjoy 设置里换一个快捷键
> 6. 最后告诉我：签名身份、权限状态、数据位置、怎么卸载

### English

> Install Shotjoy on this Mac:
> 1. Clone https://github.com/JesseWeb/Shotjoy to ~/Developer/Shotjoy
> 2. Read AGENTS.md in the repo, then run `swift test` and `./scripts/make-app.sh release`
> 3. Install `dist/Shotjoy.app` to /Applications and launch it
> 4. Walk me through the Screen Recording grant in System Settings → Privacy & Security, then verify a real ⌃⌘A capture and paste
> 5. If another app owns ⌃⌘A, change Shotjoy's shortcut in Settings
> 6. Tell me which signing identity was used, the permission state, where data lives, and how to uninstall

## What the agent will do

1. Check macOS/Xcode versions.
2. `git clone https://github.com/JesseWeb/Shotjoy.git` into a working folder.
3. `swift test` (23 core tests, no UI) and `./scripts/make-app.sh release`.
4. Copy the bundle to `/Applications/Shotjoy.app` and launch it.
5. Ask you to switch Shotjoy on under
   **System Settings → Privacy & Security → Screen Recording**.
6. Press `⌃⌘A`, select a region, click **Done**, and paste into TextEdit.
7. Optionally build `dist/Shotjoy-1.0.3.dmg` with `./scripts/make-dmg.sh release`.

## What the agent cannot do for you

- Flip the Screen Recording switch. macOS only accepts that from a human in
  System Settings.
- Unlock the screen. Overlay windows cannot receive clicks while macOS is locked.
- Approve the login item, if you enable *Launch at Login*.

## If something goes wrong

| Message | Meaning |
|---|---|
| `xcodebuild: error: tool 'xcodebuild' requires Xcode` | Only Command Line Tools are installed — install Xcode |
| The Screen Recording switch is on but Shotjoy still asks | Ad-hoc signature changed after a rebuild: menu-bar icon → **Fix Screen Recording Permission…** |
| `⌃⌘A` does nothing | Another app owns the shortcut: quit it or change Shotjoy's shortcut in Settings |
| The overlay appears but clicks do nothing | The screen is locked, or another app is in a secure-input state: unlock and retry |
| Scrolling capture has a seam | Scroll more slowly, or select a region with more texture |

Everything here is also in [`AGENTS.md`](../AGENTS.md) and the
[`README`](../README.md).
