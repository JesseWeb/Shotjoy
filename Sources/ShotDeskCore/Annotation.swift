import CoreGraphics
import Foundation

public struct RGBAColor: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let red = RGBAColor(red: 0.96, green: 0.26, blue: 0.26)
    public static let orange = RGBAColor(red: 1.0, green: 0.58, blue: 0.12)
    public static let yellow = RGBAColor(red: 1.0, green: 0.82, blue: 0.12)
    public static let green = RGBAColor(red: 0.18, green: 0.78, blue: 0.44)
    public static let blue = RGBAColor(red: 0.20, green: 0.52, blue: 1.0)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1)

    public static let palette: [RGBAColor] = [.red, .orange, .yellow, .green, .blue, .white]
}

public struct Annotation: Identifiable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case rectangle
        case ellipse
        case arrow
        case pen
        case mosaic
        case text
    }

    public let id: UUID
    public var kind: Kind
    /// Anchor in global Quartz coordinates.
    public var start: CGPoint
    /// End point in global Quartz coordinates.
    public var end: CGPoint
    /// Freehand points, also in global Quartz coordinates.
    public var points: [CGPoint]
    public var text: String
    public var color: RGBAColor
    /// Width in global points. The final renderer multiplies this by the
    /// output scale so Retina output keeps the same visual weight.
    public var lineWidth: CGFloat

    public init(
        id: UUID = UUID(),
        kind: Kind,
        start: CGPoint,
        end: CGPoint = .zero,
        points: [CGPoint] = [],
        text: String = "",
        color: RGBAColor = .red,
        lineWidth: CGFloat = 3
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.points = points
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
    }

    public var bounds: CGRect {
        switch kind {
        case .rectangle, .ellipse, .mosaic:
            return SelectionGeometry.normalized(from: start, to: end)
                .insetBy(dx: -lineWidth, dy: -lineWidth)
        case .arrow, .pen:
            let all = points.isEmpty ? [start, end] : points
            guard let first = all.first else { return .zero }
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in all {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                .insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)
        case .text:
            let width = max(24, CGFloat(text.count) * 11)
            return CGRect(x: start.x, y: start.y, width: width, height: 26)
        }
    }

    public func translated(by delta: CGPoint) -> Annotation {
        var copy = self
        copy.start = CGPoint(x: start.x + delta.x, y: start.y + delta.y)
        copy.end = CGPoint(x: end.x + delta.x, y: end.y + delta.y)
        copy.points = points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
        return copy
    }
}

public struct AnnotationStack: Equatable, Sendable {
    public private(set) var annotations: [Annotation] = []
    public var maximumCount: Int = 200

    public init() {}

    public var canUndo: Bool { !annotations.isEmpty }

    public mutating func add(_ annotation: Annotation) {
        annotations.append(annotation)
        if annotations.count > maximumCount {
            annotations.removeFirst(annotations.count - maximumCount)
        }
    }

    @discardableResult
    public mutating func undo() -> Annotation? {
        annotations.popLast()
    }

    public mutating func clear() {
        annotations.removeAll()
    }

    public func hitTest(_ point: CGPoint) -> Annotation? {
        annotations.reversed().first { $0.bounds.contains(point) }
    }
}
