import CoreGraphics
import Foundation
import Vision

enum VisionAnalyzer {
    static func recognizeText(in image: CGImage, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
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
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                DispatchQueue.main.async { completion(text) }
            } catch {
                DispatchQueue.main.async { completion("") }
            }
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
