import AppKit
import CoreGraphics
import Foundation
import ShotDeskCore

enum ImageSampling {
    /// Reads one pixel. `point` is in image pixel coordinates with the origin
    /// at the top-left, which is how screenshot images are laid out.
    static func color(in image: CGImage, atPixel point: CGPoint) -> RGBAColor? {
        let x = Int(point.x.rounded(.down))
        let y = Int(point.y.rounded(.down))
        guard x >= 0, y >= 0, x < image.width, y < image.height else { return nil }

        guard let crop = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            return nil
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .none
        context.draw(crop, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return RGBAColor(
            red: Double(pixel[0]) / 255,
            green: Double(pixel[1]) / 255,
            blue: Double(pixel[2]) / 255,
            alpha: Double(pixel[3]) / 255
        )
    }

    static func averageColor(in image: CGImage, aroundPixel point: CGPoint, radius: Int = 2) -> RGBAColor? {
        let side = max(1, radius * 2 + 1)
        let x = Int(point.x.rounded(.down)) - radius
        let y = Int(point.y.rounded(.down)) - radius
        let rect = CGRect(x: x, y: y, width: side, height: side).intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard rect.width >= 1, rect.height >= 1, let crop = image.cropping(to: rect) else {
            return color(in: image, atPixel: point)
        }

        var bytes = [UInt8](repeating: 0, count: Int(rect.width * rect.height) * 4)
        let width = Int(rect.width)
        let height = Int(rect.height)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return color(in: image, atPixel: point) }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))

        var r = 0, g = 0, b = 0, a = 0
        for i in stride(from: 0, to: bytes.count, by: 4) {
            r += Int(bytes[i]); g += Int(bytes[i + 1]); b += Int(bytes[i + 2]); a += Int(bytes[i + 3])
        }
        let count = width * height
        return RGBAColor(
            red: Double(r) / Double(count) / 255,
            green: Double(g) / Double(count) / 255,
            blue: Double(b) / Double(count) / 255,
            alpha: Double(a) / Double(count) / 255
        )
    }

    static func cropped(_ image: CGImage, toPixelRect rect: CGRect) -> CGImage? {
        let integral = rect.integral.intersection(
            CGRect(x: 0, y: 0, width: image.width, height: image.height)
        )
        guard integral.width >= 1, integral.height >= 1 else { return nil }
        return image.cropping(to: integral)
    }

    static func hexString(_ color: RGBAColor) -> String {
        let r = Int((color.red * 255).rounded())
        let g = Int((color.green * 255).rounded())
        let b = Int((color.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

extension RGBAColor {
    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var cgColor: CGColor {
        nsColor.cgColor
    }
}
