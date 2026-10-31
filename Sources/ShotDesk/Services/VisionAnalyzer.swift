import CoreGraphics
import Foundation
import Vision

enum VisionAnalyzer {
    static func recognizeText(in image: CGImage, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Prefer the user's likely languages, but fall back to Vision's
            // own default if a language pack is unavailable on this Mac.
            var text = performText(on: image, languages: ["zh-Hans", "zh-Hant", "en-US"])
            if text.isEmpty {
                text = performText(on: image, languages: nil)
            }
            DispatchQueue.main.async { completion(text) }
        }
    }

    private static func performText(on image: CGImage, languages: [String]?) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if let languages {
            request.recognitionLanguages = languages
        }
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            let observations = (request.results ?? []).sorted {
                if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        } catch {
            return ""
        }
    }

    static func detectQRCode(in image: CGImage, completion: @escaping ([String]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [
                .qr, .aztec, .pdf417, .code128, .code39, .code93,
                .ean13, .ean8, .upce, .itf14, .dataMatrix
            ]
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
                let values = (request.results ?? []).compactMap(\.payloadStringValue)
                DispatchQueue.main.async { completion(values) }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    static func detectFaces(in image: CGImage, completion: @escaping ([CGRect]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
                let faces = (request.results ?? []).map(\.boundingBox)
                DispatchQueue.main.async { completion(faces) }
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
}
