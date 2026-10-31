import AppKit
import CoreGraphics
import ScreenCaptureKit

struct CapturedScreen {
    let displayID: CGDirectDisplayID
    /// Global Quartz rect (origin at the top-left of the main display).
    let bounds: CGRect
    /// Native pixels per point (usually 1 or 2).
    let scale: CGFloat
    let image: CGImage
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case noDisplays
    case captureFailed(String)
    case noImage

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return L10n.permissionBody
        case .noDisplays:
            return "No displays are available for capture."
        case .captureFailed(let reason):
            return "Screen capture failed: \(reason)"
        case .noImage:
            return "The display returned an empty image."
        }
    }
}

/// Captures every display at native resolution.
///
/// WeChat 4.1 imports both the legacy `CGDisplayCreateImage` family and the
/// modern `SCScreenshotManager` / `SCShareableContent` APIs. ShotDesk follows
/// the same two-tier approach: prefer ScreenCaptureKit on macOS 14+, fall back
/// to CoreGraphics if ScreenCaptureKit is unavailable or fails.
enum ScreenCaptureService {
    static var hasPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    static func openPermissionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    static func captureAll() async throws -> [CapturedScreen] {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        if #available(macOS 14.0, *) {
            do {
                let screens = try await captureWithScreenCaptureKit()
                if !screens.isEmpty { return screens }
            } catch {
                // Fall through to CoreGraphics. This also makes the app work on
                // machines where SCK is blocked by a policy profile.
            }
        }
        return try captureWithCoreGraphics()
    }

    /// Capture a rectangle in global Quartz coordinates. Used by scrolling
    /// capture, where the selection is always on one display.
    static func capture(rect: CGRect) async throws -> CGImage {
        guard hasPermission else { throw ScreenCaptureError.permissionDenied }
        guard let screen = NSScreen.screens.first(where: {
            displayBounds(for: $0).contains(CGPoint(x: rect.midX, y: rect.midY))
        }) else {
            throw ScreenCaptureError.noDisplays
        }
        let bounds = displayBounds(for: screen)
        let displayID = displayID(for: screen)
        let local = CGRect(
            x: rect.minX - bounds.minX,
            y: rect.minY - bounds.minY,
            width: rect.width,
            height: rect.height
        )
        // On macOS 15.2+ ScreenCaptureKit can capture an arbitrary rect and
        // returns a native-resolution image. The legacy display API is only a
        // fallback for older systems (it is obsoleted in the macOS 15 SDK).
        if #available(macOS 15.2, *), let image = try? await captureRectWithScreenCaptureKit(rect) {
            return image
        }
        if let image = CGDisplayCreateImage(displayID, rect: local) {
            return image
        }
        throw ScreenCaptureError.noImage
    }

    // MARK: - ScreenCaptureKit

    @available(macOS 14.0, *)
    private static func captureWithScreenCaptureKit() async throws -> [CapturedScreen] {
        let content = try await shareableContent()
        var results: [CapturedScreen] = []
        for display in content.displays {
            let bounds = CGDisplayBounds(display.displayID)
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()

            // SCDisplay.width is documented as pixels, but on some macOS
            // builds it reports points. Compare it with the display bounds and
            // only scale when it looks like points.
            let screenScale = NSScreen.screens
                .first(where: { displayID(for: $0) == display.displayID })?
                .backingScaleFactor ?? 2
            let looksLikePoints = abs(CGFloat(display.width) - bounds.width) < 2
            let targetWidth = looksLikePoints
                ? Int((bounds.width * screenScale).rounded())
                : display.width
            let targetHeight = looksLikePoints
                ? Int((bounds.height * screenScale).rounded())
                : display.height

            config.width = max(1, targetWidth)
            config.height = max(1, targetHeight)
            config.showsCursor = false
            config.captureResolution = .best
            config.scalesToFit = false
            let image = try await screenshot(filter: filter, config: config)
            let scale = bounds.width > 0 ? CGFloat(image.width) / bounds.width : 1
            results.append(
                CapturedScreen(
                    displayID: display.displayID,
                    bounds: bounds,
                    scale: scale,
                    image: image
                )
            )
        }
        return results
    }

    @available(macOS 15.2, *)
    private static func captureRectWithScreenCaptureKit(_ rect: CGRect) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? ScreenCaptureError.noImage)
                }
            }
        }
    }

    @available(macOS 14.0, *)
    private static func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: error ?? ScreenCaptureError.captureFailed("No shareable content"))
                }
            }
        }
    }

    @available(macOS 14.0, *)
    private static func screenshot(filter: SCContentFilter, config: SCStreamConfiguration) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? ScreenCaptureError.noImage)
                }
            }
        }
    }

    // MARK: - CoreGraphics fallback

    private static func captureWithCoreGraphics() throws -> [CapturedScreen] {
        var results: [CapturedScreen] = []
        for screen in NSScreen.screens {
            let id = displayID(for: screen)
            let bounds = displayBounds(for: screen)
            guard let image = CGDisplayCreateImage(id) else {
                throw ScreenCaptureError.captureFailed("CGDisplayCreateImage returned nil")
            }
            let scale = bounds.width > 0 ? CGFloat(image.width) / bounds.width : 1
            results.append(CapturedScreen(displayID: id, bounds: bounds, scale: scale, image: image))
        }
        if results.isEmpty { throw ScreenCaptureError.noDisplays }
        return results
    }

    // MARK: - Helpers

    static func displayID(for screen: NSScreen) -> CGDirectDisplayID {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            ?? CGMainDisplayID()
    }

    static func displayBounds(for screen: NSScreen) -> CGRect {
        CGDisplayBounds(displayID(for: screen))
    }

    static var mainScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static var canvasBounds: CGRect {
        NSScreen.screens
            .map { displayBounds(for: $0) }
            .reduce(CGRect.null) { $0.union($1) }
    }
}
