import AppKit
import CoreGraphics
import ShotDeskCore

final class OverlayView: NSView {
    let screen: CapturedScreen
    weak var session: CaptureSession?

    private var trackingAreaRef: NSTrackingArea?

    init(screen: CapturedScreen, session: CaptureSession) {
        self.screen = screen
        self.session = session
        super.init(frame: CGRect(origin: .zero, size: screen.bounds.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let session, let context = NSGraphicsContext.current?.cgContext else { return }

        // The desktop, dimmed.
        drawScreenImage(in: context, clippedTo: nil)
        NSColor.black.withAlphaComponent(0.42).setFill()
        bounds.fill()

        let localSelection = session.selection.map {
            $0.offsetBy(dx: -screen.bounds.minX, dy: -screen.bounds.minY)
        }

        if let localSelection, localSelection.intersects(bounds) {
            drawScreenImage(in: context, clippedTo: localSelection)
            context.saveGState()
            context.clip(to: localSelection)
            AnnotationRenderer.draw(
                annotations: session.annotations.annotations,
                in: context,
                transform: { CGPoint(x: $0.x - self.screen.bounds.minX, y: $0.y - self.screen.bounds.minY) },
                lineScale: 1,
                sampler: { [weak self] point in
                    guard let self else { return nil }
                    let pixel = CGPoint(
                        x: (point.x - self.screen.bounds.minX) * self.screen.scale,
                        y: (point.y - self.screen.bounds.minY) * self.screen.scale
                    )
                    return ImageSampling.averageColor(in: self.screen.image, aroundPixel: pixel, radius: 2)
                }
            )
            context.restoreGState()
            drawSelectionBorder(localSelection, in: context)
            drawHandles(localSelection, in: context)
        } else if let hover = session.hoverWindowRect {
            let local = hover.offsetBy(dx: -screen.bounds.minX, dy: -screen.bounds.minY)
            if local.intersects(bounds) {
                NSColor.systemBlue.withAlphaComponent(0.12).setFill()
                local.fill()
                let path = NSBezierPath(roundedRect: local.insetBy(dx: 0.75, dy: 0.75), xRadius: 4, yRadius: 4)
                path.lineWidth = 1.5
                NSColor.systemBlue.setStroke()
                path.stroke()
            }
        }

        if session.showsMagnifier {
            drawCrosshair(in: context)
            drawMagnifier(for: session.cursorPoint, in: context, session: session)
        }
    }

    private func drawScreenImage(in context: CGContext, clippedTo rect: CGRect?) {
        context.saveGState()
        if let rect {
            context.clip(to: rect)
        }
        context.interpolationQuality = .high
        CGDrawing.drawImage(screen.image, in: bounds, context: context, flipped: true)
        context.restoreGState()
    }

    private func drawSelectionBorder(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.95).cgColor)
        context.setLineWidth(3)
        context.stroke(rect.insetBy(dx: -0.5, dy: -0.5))
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(1.5)
        context.stroke(rect.insetBy(dx: 0.25, dy: 0.25))
        context.restoreGState()
    }

    private func drawHandles(_ rect: CGRect, in context: CGContext) {
        for handle in SelectionHandle.allCases {
            let handleRect = SelectionGeometry.handleRect(handle, in: rect, size: 8)
            let path = NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2)
            NSColor.white.setFill()
            path.fill()
            NSColor.systemBlue.setStroke()
            path.lineWidth = 1.25
            path.stroke()
        }
    }

    private func drawCrosshair(in context: CGContext) {
        guard let session else { return }
        let point = CGPoint(
            x: session.cursorPoint.x - screen.bounds.minX,
            y: session.cursorPoint.y - screen.bounds.minY
        )
        guard bounds.contains(point) else { return }
        context.saveGState()
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1.5)
        context.move(to: CGPoint(x: 0, y: point.y))
        context.addLine(to: CGPoint(x: bounds.width, y: point.y))
        context.move(to: CGPoint(x: point.x, y: 0))
        context.addLine(to: CGPoint(x: point.x, y: bounds.height))
        context.strokePath()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(0.75)
        context.move(to: CGPoint(x: 0, y: point.y))
        context.addLine(to: CGPoint(x: bounds.width, y: point.y))
        context.move(to: CGPoint(x: point.x, y: 0))
        context.addLine(to: CGPoint(x: point.x, y: bounds.height))
        context.strokePath()
        context.restoreGState()
    }

    private func drawMagnifier(for globalPoint: CGPoint, in context: CGContext, session: CaptureSession) {
        let point = CGPoint(
            x: globalPoint.x - screen.bounds.minX,
            y: globalPoint.y - screen.bounds.minY
        )
        guard bounds.contains(point) else { return }

        let side: CGFloat = 116
        var origin = CGPoint(x: point.x + 24, y: point.y + 24)
        if origin.x + side > bounds.width - 8 { origin.x = point.x - side - 24 }
        if origin.y + side + 30 > bounds.height - 8 { origin.y = point.y - side - 30 }
        origin.x = max(8, min(origin.x, bounds.width - side - 8))
        origin.y = max(8, min(origin.y, bounds.height - side - 30))
        let frame = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let labelFrame = CGRect(x: frame.minX, y: frame.maxY + 6, width: side, height: 24)

        let rounded = NSBezierPath(roundedRect: frame, xRadius: 8, yRadius: 8)
        NSColor.black.withAlphaComponent(0.9).setFill()
        rounded.fill()

        let sourceSide: CGFloat = 36
        let pixelCenter = CGPoint(
            x: (point.x) * screen.scale,
            y: (point.y) * screen.scale
        )
        let sourcePixels = CGRect(
            x: pixelCenter.x - sourceSide * screen.scale / 2,
            y: pixelCenter.y - sourceSide * screen.scale / 2,
            width: sourceSide * screen.scale,
            height: sourceSide * screen.scale
        ).intersection(CGRect(x: 0, y: 0, width: screen.image.width, height: screen.image.height))
        if sourcePixels.width > 1, sourcePixels.height > 1,
           let crop = screen.image.cropping(to: sourcePixels) {
            context.saveGState()
            rounded.addClip()
            context.interpolationQuality = .none
            CGDrawing.drawImage(crop, in: frame, context: context, flipped: true)
            context.restoreGState()
        }

        context.saveGState()
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        context.move(to: CGPoint(x: center.x - 9, y: center.y))
        context.addLine(to: CGPoint(x: center.x - 3, y: center.y))
        context.move(to: CGPoint(x: center.x + 3, y: center.y))
        context.addLine(to: CGPoint(x: center.x + 9, y: center.y))
        context.move(to: CGPoint(x: center.x, y: center.y - 9))
        context.addLine(to: CGPoint(x: center.x, y: center.y - 3))
        context.move(to: CGPoint(x: center.x, y: center.y + 3))
        context.addLine(to: CGPoint(x: center.x, y: center.y + 9))
        context.strokePath()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.addPath(rounded.cgPath)
        context.strokePath()
        context.restoreGState()

        let pixel = CGPoint(
            x: (globalPoint.x - screen.bounds.minX) * screen.scale,
            y: (globalPoint.y - screen.bounds.minY) * screen.scale
        )
        let color = ImageSampling.color(in: screen.image, atPixel: pixel) ?? .white
        let text = "\(ImageSampling.hexString(color))   \(Int(globalPoint.x)), \(Int(globalPoint.y))"

        let labelPath = NSBezierPath(roundedRect: labelFrame, xRadius: 6, yRadius: 6)
        NSColor.black.withAlphaComponent(0.82).setFill()
        labelPath.fill()

        NSColor.white.setFill()
        let swatch = CGRect(x: labelFrame.minX + 6, y: labelFrame.minY + 6, width: 12, height: 12)
        NSBezierPath(roundedRect: swatch, xRadius: 2, yRadius: 2).fill()
        color.nsColor.setFill()
        NSBezierPath(roundedRect: swatch.insetBy(dx: 1, dy: 1), xRadius: 1.5, yRadius: 1.5).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        NSAttributedString(string: text, attributes: attributes)
            .draw(at: CGPoint(x: labelFrame.minX + 24, y: labelFrame.minY + 5))
    }

    // MARK: - Events

    private func globalPoint(for event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CGPoint(x: local.x + screen.bounds.minX, y: local.y + screen.bounds.minY)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        session?.mouseDown(at: globalPoint(for: event), in: self, clickCount: event.clickCount)
    }

    override func mouseDragged(with event: NSEvent) {
        session?.mouseDragged(to: globalPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        session?.mouseUp(at: globalPoint(for: event))
    }

    override func mouseMoved(with event: NSEvent) {
        session?.mouseMoved(to: globalPoint(for: event))
    }

    override func rightMouseDown(with event: NSEvent) {
        session?.cancel()
    }

    override func keyDown(with event: NSEvent) {
        guard session?.handleKey(event) != true else { return }
        super.keyDown(with: event)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
