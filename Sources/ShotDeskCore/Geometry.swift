import CoreGraphics

/// Handles around a selection rectangle. The raw values are stable because
/// they are also used as cursor-rect keys.
public enum SelectionHandle: Int, CaseIterable, Sendable {
    case topLeft = 0
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left

    public var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomRight, .bottomLeft:
            return true
        default:
            return false
        }
    }
}

public enum SelectionGeometry {
    /// A small rectangle around a handle, in the same coordinate space as
    /// `rect`. Handles are drawn half outside the selection, like WeChat.
    public static func handleRect(_ handle: SelectionHandle, in rect: CGRect, size: CGFloat = 8) -> CGRect {
        let half = size / 2
        let points = handlePoints(in: rect)
        let p = points[handle] ?? .zero
        return CGRect(x: p.x - half, y: p.y - half, width: size, height: size)
    }

    public static func handlePoints(in rect: CGRect) -> [SelectionHandle: CGPoint] {
        [
            .topLeft: CGPoint(x: rect.minX, y: rect.minY),
            .top: CGPoint(x: rect.midX, y: rect.minY),
            .topRight: CGPoint(x: rect.maxX, y: rect.minY),
            .right: CGPoint(x: rect.maxX, y: rect.midY),
            .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY),
            .bottom: CGPoint(x: rect.midX, y: rect.maxY),
            .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY),
            .left: CGPoint(x: rect.minX, y: rect.midY)
        ]
    }

    /// Returns the handle under `point`, if any. Corner handles win over edges
    /// because they are checked first.
    public static func handle(at point: CGPoint, in rect: CGRect, tolerance: CGFloat = 10) -> SelectionHandle? {
        let ordered: [SelectionHandle] = [
            .topLeft, .topRight, .bottomRight, .bottomLeft,
            .top, .right, .bottom, .left
        ]
        for handle in ordered where handleRect(handle, in: rect, size: tolerance * 2).contains(point) {
            return handle
        }
        return nil
    }

    public static func normalized(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    public static func clamped(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width)
        let height = min(rect.height, bounds.height)
        let x = min(max(rect.minX, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func moved(_ rect: CGRect, by delta: CGPoint, within bounds: CGRect) -> CGRect {
        clamped(rect.offsetBy(dx: delta.x, dy: delta.y), to: bounds)
    }

    public static func resized(
        _ rect: CGRect,
        handle: SelectionHandle,
        to point: CGPoint,
        minSize: CGFloat = 4,
        within bounds: CGRect
    ) -> CGRect {
        var minX = rect.minX
        var minY = rect.minY
        var maxX = rect.maxX
        var maxY = rect.maxY

        switch handle {
        case .topLeft:
            minX = point.x; minY = point.y
        case .top:
            minY = point.y
        case .topRight:
            maxX = point.x; minY = point.y
        case .right:
            maxX = point.x
        case .bottomRight:
            maxX = point.x; maxY = point.y
        case .bottom:
            maxY = point.y
        case .bottomLeft:
            minX = point.x; maxY = point.y
        case .left:
            minX = point.x
        }

        minX = min(max(minX, bounds.minX), bounds.maxX)
        maxX = min(max(maxX, bounds.minX), bounds.maxX)
        minY = min(max(minY, bounds.minY), bounds.maxY)
        maxY = min(max(maxY, bounds.minY), bounds.maxY)

        if maxX - minX < minSize {
            if handle == .topLeft || handle == .bottomLeft || handle == .left {
                minX = maxX - minSize
            } else {
                maxX = minX + minSize
            }
        }
        if maxY - minY < minSize {
            if handle == .topLeft || handle == .topRight || handle == .top {
                minY = maxY - minSize
            } else {
                maxY = minY + minSize
            }
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// macOS has two global coordinate spaces: AppKit counts from the bottom-left
/// of the main display, while Quartz/CoreGraphics (and every screen-capture
/// API we use) count from the top-left. Keeping one conversion point in the
/// codebase makes multi-display maths much less error-prone.
public enum GlobalCoordinates {
    public static func cocoaToQuartz(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: mainScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func quartzToCocoa(_ rect: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.minX,
            y: mainScreenHeight - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }

    public static func cocoaToQuartz(_ point: CGPoint, mainScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenHeight - point.y)
    }

    public static func quartzToCocoa(_ point: CGPoint, mainScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: mainScreenHeight - point.y)
    }
}

public enum RectMath {
    /// The scale needed to fit `rect` inside `bounds` without cropping.
    public static func aspectFitScale(_ rect: CGRect, in bounds: CGRect) -> CGFloat {
        guard rect.width > 0, rect.height > 0 else { return 1 }
        return min(bounds.width / rect.width, bounds.height / rect.height)
    }

    public static func centered(_ rect: CGRect, in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.midX - rect.width / 2,
            y: bounds.midY - rect.height / 2,
            width: rect.width,
            height: rect.height
        )
    }
}
