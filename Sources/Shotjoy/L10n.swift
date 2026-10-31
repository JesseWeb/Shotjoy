import Foundation

/// A deliberately tiny localization layer. Shotjoy ships two UI languages
/// (Simplified Chinese and English) and picks one from the system preference;
/// no resource bundles are needed, which keeps `make-app.sh` simple.
enum L10n {
    static var isChinese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true
    }

    static func t(_ chinese: String, _ english: String) -> String {
        isChinese ? chinese : english
    }

    static var appName: String { "Shotjoy" }

    static var screenshot: String { t("截图", "Screenshot") }
    static var captureWindow: String { t("窗口截图", "Capture Window") }
    static var pinLast: String { t("置顶上一张截图", "Pin Last Screenshot") }
    static var saveLast: String { t("保存上一张截图…", "Save Last Screenshot…") }
    static var recognizeText: String { t("识别文字", "Recognize Text") }
    static var scanQRCode: String { t("识别二维码", "Scan QR Code") }
    static var settings: String { t("设置…", "Settings…") }
    static var launchAtLogin: String { t("开机时打开", "Launch at Login") }
    static var about: String { t("关于 Shotjoy（截趣）", "About Shotjoy") }
    static var quit: String { t("退出 Shotjoy", "Quit Shotjoy") }
    static var fixScreenPermission: String { t("修复屏幕录制权限…", "Fix Screen Recording Permission…") }
    static var checkPermission: String { t("检查屏幕录制权限…", "Check Screen Recording Permission…") }
    static var permissionTitle: String { t("需要屏幕录制权限", "Screen Recording Permission Needed") }
    static var permissionBody: String {
        t(
            "Shotjoy（截趣）需要「屏幕录制」权限才能截图。请在「系统设置 → 隐私与安全性 → 屏幕录制」中打开 Shotjoy，然后重新截图。",
            "Shotjoy needs Screen Recording permission to take screenshots. Turn Shotjoy on in System Settings → Privacy & Security → Screen Recording, then try again."
        )
    }
    static var openSettings: String { t("打开系统设置", "Open System Settings") }
    static var retry: String { t("重试", "Retry") }
    static var cancel: String { t("取消", "Cancel") }
    static var done: String { t("完成", "Done") }
    static var copy: String { t("复制", "Copy") }
    static var save: String { t("保存", "Save") }
    static var pin: String { t("置顶", "Pin") }
    static var close: String { t("关闭", "Close") }
    static var copied: String { t("已复制到剪贴板", "Copied to clipboard") }
    static var saved: String { t("已保存", "Saved") }
    static var noText: String { t("没有识别到文字", "No text recognized") }
    static var noQRCode: String { t("没有识别到二维码", "No QR code found") }
    static var hotKeyFailed: String { t("快捷键注册失败", "Shortcut Unavailable") }
    static var hotKeyFailedBody: String {
        t(
            "这个快捷键可能已被其他应用占用。请在设置中换一个组合，或退出占用它的应用。",
            "Another app may already own this shortcut. Choose a different combination in Settings, or quit the app that owns it."
        )
    }
    static var shortcut: String { t("快捷键", "Shortcut") }
    static var record: String { t("录制", "Record") }
    static var pressShortcut: String { t("请按下新的快捷键…", "Press the new shortcut…") }
    static var copyAfterCapture: String { t("截图后自动复制到剪贴板", "Copy to clipboard after capture") }
    static var playSound: String { t("播放截图声音", "Play capture sound") }
    static var saveToDesktop: String { t("完成后自动保存到桌面", "Automatically save to Desktop") }
    static var scrollingCapture: String { t("滚动截图", "Scrolling Capture") }
    static var scrollInstructions: String {
        t("在选区中滚动页面，完成后点「完成」", "Scroll inside the selection, then click Done")
    }
    static var stitchFailed: String { t("拼接失败：没有找到重叠区域", "Could not stitch: no overlapping region found") }
    static var longScreenshot: String { t("长截图", "Long Screenshot") }
    static var recognize: String { t("识别", "Recognize") }
    static var aiMask: String { t("AI 人脸打码", "AI Face Masking") }
    static var noFacesDetected: String { t("未检测到人脸", "No faces detected") }
    static var facesMasked: String { t("已为人脸打码", "Faces masked") }
    static var maskFailed: String { t("打码失败", "Masking failed") }
    static var moveSelect: String { t("移动 / 选择", "Move / Select") }
    static var undo: String { t("撤销", "Undo") }
    static var text: String { t("文字", "Text") }
    static var mosaic: String { t("马赛克", "Mosaic") }
    static var brush: String { t("画笔", "Brush") }
    static var arrow: String { t("箭头", "Arrow") }
    static var ellipse: String { t("椭圆", "Ellipse") }
    static var rectangle: String { t("矩形", "Rectangle") }
    static var color: String { t("颜色", "Color") }
    static var captureTip: String {
        t("拖动选择区域，单击窗口可直接截图；Esc 取消", "Drag to select, click a window to capture it; Esc to cancel")
    }
    static var permissionsHint: String {
        t("截图权限由 macOS 管理；重新签名后可能需要重新授权。", "Screen Recording is managed by macOS; a re-signed build may need a fresh grant.")
    }
}
