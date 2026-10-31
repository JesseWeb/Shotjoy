import Foundation

/// A deliberately small localization layer. The app supports English,
/// Simplified Chinese, Traditional Chinese, Japanese, French and Spanish; the
/// active language can follow the system or be chosen in Settings.
enum L10n {
    static var current: AppLanguage { LanguageManager.shared.resolved }

    static var isChinese: Bool {
        current == .simplifiedChinese || current == .traditionalChinese
    }

    static func t(_ chinese: String, _ english: String) -> String {
        switch current {
        case .english:
            return english
        case .simplifiedChinese:
            return chinese
        case .traditionalChinese:
            return Translations.text(english, language: .traditionalChinese) ?? chinese
        case .japanese, .french, .spanish:
            return Translations.text(english, language: current) ?? english
        case .system:
            return english
        }
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
    static var fixPermissionShort: String { t("修复权限…", "Fix Permission…") }
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
    static var language: String { t("语言", "Language") }
    static var followSystem: String { t("跟随系统", "Follow System") }
    static var ok: String { t("好", "OK") }
    static var captureTip: String {
        t("拖动选择区域，单击窗口可直接截图；Esc 取消", "Drag to select, click a window to capture it; Esc to cancel")
    }
    static var permissionsHint: String {
        t("截图权限由 macOS 管理；重新签名后可能需要重新授权。", "Screen Recording is managed by macOS; a re-signed build may need a fresh grant.")
    }

    static func framesCaptured(_ count: Int) -> String {
        switch current {
        case .simplifiedChinese:
            return "已捕获 \(count) 帧"
        case .traditionalChinese:
            return "已擷取 \(count) 幀"
        case .japanese:
            return "\(count) フレームを取得しました"
        case .french:
            return "\(count) images capturées"
        case .spanish:
            return "\(count) fotogramas capturados"
        case .english, .system:
            return "\(count) frames captured"
        }
    }

    static func aboutBody(shortcut: String) -> String {
        switch current {
        case .simplifiedChinese:
            return "一个快速、纯本地的 macOS 截图工具。\n\n快捷键：\(shortcut)\n屏幕录制权限由 macOS 管理。"
        case .traditionalChinese:
            return "一個快速、純本機的 macOS 截圖工具。\n\n快速鍵：\(shortcut)\n螢幕錄製權限由 macOS 管理。"
        case .japanese:
            return "高速でローカル完結の macOS スクリーンショットツール。\n\nショートカット：\(shortcut)\n画面収録の権限は macOS が管理します。"
        case .french:
            return "Un outil de capture d'écran macOS rapide et 100 % local.\n\nRaccourci : \(shortcut)\nL'enregistrement de l'écran est géré par macOS."
        case .spanish:
            return "Una herramienta de captura de pantalla macOS rápida y totalmente local.\n\nAtajo: \(shortcut)\nLa grabación de pantalla la gestiona macOS."
        case .english, .system:
            return "A fast, local-only macOS screenshot tool.\n\nShortcut: \(shortcut)\nScreen Recording is managed by macOS."
        }
    }
}
