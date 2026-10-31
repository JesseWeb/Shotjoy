import XCTest
@testable import ShotDeskCore

final class FrameStitcherTests: XCTestCase {
    /// Deterministic pseudo-random bytes so every row has a distinct signature.
    private func makeImage(height: Int, width: Int = 24, seed: UInt32 = 1) -> [UInt8] {
        var state = seed
        var bytes: [UInt8] = []
        bytes.reserveCapacity(width * height)
        for _ in 0..<(width * height) {
            state = 1664525 &* state &+ 1013904223
            bytes.append(UInt8((state >> 24) & 0xFF))
        }
        return bytes
    }

    private func slice(_ image: [UInt8], width: Int, from: Int, height: Int) -> [UInt8] {
        Array(image[(from * width)..<((from + height) * width)])
    }

    func testFindsOverlapBetweenScrolledFrames() {
        let width = 24
        let full = makeImage(height: 120, width: width)
        let frameA = Array(full[0..<(40 * width)])
        let frameB = Array(full[(30 * width)..<(70 * width)])

        let sigA = FrameStitcher.signature(gray: frameA, width: width, height: 40)
        let sigB = FrameStitcher.signature(gray: frameB, width: width, height: 40)
        XCTAssertEqual(FrameStitcher.findOverlap(existing: sigA, new: sigB), 10)
    }

    func testPlanProducesExpectedHeight() {
        let plan = FrameStitcher.plan(heights: [40, 40, 40], overlaps: [10, 10])
        XCTAssertEqual(plan.offsets, [0, 30, 60])
        XCTAssertEqual(plan.totalHeight, 100)
    }

    func testNonOverlappingFramesAppend() {
        let width = 24
        let a = makeImage(height: 40, width: width, seed: 1)
        let b = makeImage(height: 40, width: width, seed: 99)
        let sigA = FrameStitcher.signature(gray: a, width: width, height: 40)
        let sigB = FrameStitcher.signature(gray: b, width: width, height: 40)
        XCTAssertEqual(FrameStitcher.findOverlap(existing: sigA, new: sigB), 0)
    }

    func testIdenticalFramesFullyOverlap() {
        let width = 16
        let a = makeImage(height: 32, width: width, seed: 7)
        let sig = FrameStitcher.signature(gray: a, width: width, height: 32)
        XCTAssertEqual(FrameStitcher.findOverlap(existing: sig, new: sig), 32)
    }

    func testFullOverlapRequiresExactRows() {
        let width = 16
        var image = makeImage(height: 32, width: width, seed: 11)
        let signatureA = FrameStitcher.signature(gray: image, width: width, height: 32)
        image[(20 * width) + 3] ^= 0xFF
        let signatureB = FrameStitcher.signature(gray: image, width: width, height: 32)
        XCTAssertLessThan(FrameStitcher.findOverlap(existing: signatureA, new: signatureB), 32)
    }

    func testSignatureRejectsShortBuffer() {
        let sig = FrameStitcher.signature(gray: [1, 2, 3], width: 10, height: 10)
        XCTAssertTrue(sig.rows.isEmpty)
    }
}
