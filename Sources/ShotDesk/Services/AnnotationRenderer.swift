import AppKit
import CoreGraphics
import ShotDeskCore

enum AnnotationRenderer {
    /// Draws annotations into a top-left-origin (flipped) context. The same
    /// renderer is used for the live overlay and for the final Retina image,
    /// with `lineScale` bridging points and output pixels.
    static func draw(
        annotations: [Annotation],
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat,
        sampler: (CGPoint) -> RGBAColor?
    ) {
        for annotation in annotations {
            switch annotation.kind {
            case .rectangle:
                drawRectangle(annotation, in: context, transform: transform, lineScale: lineScale)
            case .ellipse:
                drawEllipse(annotation, in: context, transform: transform, lineScale: lineScale)
            case .arrow:
                drawArrow(annotation, in: context, transform: transform, lineScale: lineScale)
            case .pen:
                drawPen(annotation, in: context, transform: transform, lineScale: lineScale)
            case .mosaic:
                drawMosaic(annotation, in: context, transform: transform, lineScale: lineScale, sampler: sampler)
            case .text:
                drawText(annotation, in: context, transform: transform, lineScale: lineScale)
            }
        }
    }

    private static func pathRect(_ annotation: Annotation, transform: (CGPoint) -> CGPoint) -> CGRect {
        let a = transform(annotation.start)
        let b = transform(annotation.end)
        return SelectionGeometry.normalized(from: a, to: b)
    }

    private static func setStroke(_ context: CGContext, _ annotation: Annotation, _ lineScale: CGFloat) {
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth * lineScale)
        context.setLineCap(.round)
        context.setLineJoin(.round)
    }

    private static func drawRectangle(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat
    ) {
        let rect = pathRect(annotation, transform: transform)
        setStroke(context, annotation, lineScale)
        context.stroke(rect)
    }

    private static func drawEllipse(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat
    ) {
        let rect = pathRect(annotation, transform: transform)
        setStroke(context, annotation, lineScale)
        context.strokeEllipse(in: rect)
    }

    private static func drawArrow(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat
    ) {
        let start = transform(annotation.start)
        let end = transform(annotation.end)
        let width = annotation.lineWidth * lineScale
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength = max(10 * lineScale, width * 4)
        let headAngle = CGFloat.pi / 7

        context.setStrokeColor(annotation.color.cgColor)
        context.setFillColor(annotation.color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let p1 = CGPoint(
            x: end.x - headLength * cos(angle - headAngle),
            y: end.y - headLength * sin(angle - headAngle)
        )
        let p2 = CGPoint(
            x: end.x - headLength * cos(angle + headAngle),
            y: end.y - headLength * sin(angle + headAngle)
        )
        context.move(to: end)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }

    private static func drawPen(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat
    ) {
        let points = annotation.points.isEmpty ? [annotation.start, annotation.end] : annotation.points
        guard let first = points.first else { return }
        setStroke(context, annotation, lineScale)
        context.move(to: transform(first))
        for point in points.dropFirst() {
            context.addLine(to: transform(point))
        }
        context.strokePath()
    }

    private static func drawMosaic(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat,
        sampler: (CGPoint) -> RGBAColor?
    ) {
        let block = max(4, annotation.lineWidth * lineScale)
        if annotation.points.isEmpty {
            let globalRect = SelectionGeometry.normalized(from: annotation.start, to: annotation.end)
            guard globalRect.width > 0, globalRect.height > 0 else { return }
            var y = globalRect.minY
            while y < globalRect.maxY {
                var x = globalRect.minX
                while x < globalRect.maxX {
                    let color = sampler(CGPoint(x: x + block / 2, y: y + block / 2)) ?? RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
                    context.setFillColor(color.cgColor)
                    let origin = transform(CGPoint(x: x, y: y))
                    context.fill(CGRect(x: origin.x, y: origin.y, width: block, height: block))
                    x += block
                }
                y += block
            }
            return
        }

        for point in annotation.points {
            let color = sampler(point) ?? RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
            let center = transform(point)
            context.setFillColor(color.cgColor)
            context.fill(
                CGRect(
                    x: center.x - block / 2,
                    y: center.y - block / 2,
                    width: block,
                    height: block
                )
            )
        }
    }

    private static func drawText(
        _ annotation: Annotation,
        in context: CGContext,
        transform: (CGPoint) -> CGPoint,
        lineScale: CGFloat
    ) {
        guard !annotation.text.isEmpty else { return }
        let origin = transform(annotation.start)
        let fontSize = max(11, 18 * lineScale)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 2 * lineScale
        shadow.shadowOffset = NSSize(width: 0, height: -1 * lineScale)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: annotation.color.nsColor,
            .shadow: shadow
        ]
        let string = NSAttributedString(string: annotation.text, attributes: attributes)
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        string.draw(at: origin)
        NSGraphicsContext.current = previous
    }
}
