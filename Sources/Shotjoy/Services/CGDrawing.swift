import CoreGraphics

enum CGDrawing {
    /// Draws a CGImage upright into a context whose Y axis points down.
    /// CGImage drawing itself is defined in a bottom-left space, so a local
    /// flip is needed when the destination context is flipped.
    static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext, flipped: Bool) {
        context.saveGState()
        if flipped {
            context.translateBy(x: rect.minX, y: rect.maxY)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        } else {
            context.draw(image, in: rect)
        }
        context.restoreGState()
    }
}
