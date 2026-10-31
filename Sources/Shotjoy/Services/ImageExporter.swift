import AppKit
import CoreGraphics
import ImageIO
import ShotjoyCore
import UniformTypeIdentifiers

enum ImageExporter {
    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func copyToPasteboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let nsImage = NSImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
        pasteboard.writeObjects([nsImage])
        if let data = pngData(image) {
            pasteboard.setData(data, forType: .png)
        }
    }

    @discardableResult
    static func save(_ image: CGImage, to url: URL) throws -> URL {
        guard let data = pngData(image) else {
            throw NSError(domain: "Shotjoy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode PNG"])
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    static func uniqueURL(in directory: URL) -> URL {
        ImageNaming.uniqueURL(directory: directory)
    }

    /// Shows a save panel and writes the image. The completion runs on the main
    /// thread with the saved URL, or nil if the user cancelled.
    static func presentSavePanel(
        for image: CGImage,
        defaultDirectory: URL?,
        completion: @escaping (URL?) -> Void
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = ImageNaming.fileName()
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(nil)
                return
            }
            do {
                try save(image, to: url)
                completion(url)
            } catch {
                NSAlert(error: error).runModal()
                completion(nil)
            }
        }
    }
}
