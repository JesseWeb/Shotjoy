import Foundation

/// Row signatures used to align consecutive scrolling-capture frames.
///
/// WeChat's long screenshot code ships `GrabWorker`, `SpliceWorker` and
/// `OpenCVWorker`. Shotjoy keeps the same split: a grabber produces frames,
/// this type finds the vertical overlap, and the app splices the full-resolution
/// images. Doing the search on tiny per-row signatures keeps it fast and
/// testable without OpenCV.
public struct RowSignature: Equatable, Sendable {
    public let width: Int
    public let height: Int
    /// 16 nibbles packed into a UInt64, sampled evenly across each row.
    public let rows: [UInt64]

    public init(width: Int, height: Int, rows: [UInt64]) {
        self.width = width
        self.height = height
        self.rows = rows
    }
}

public struct StitchPlan: Equatable, Sendable {
    public let offsets: [Int]
    public let overlaps: [Int]
    public let totalHeight: Int

    public init(offsets: [Int], overlaps: [Int], totalHeight: Int) {
        self.offsets = offsets
        self.overlaps = overlaps
        self.totalHeight = totalHeight
    }
}

public enum FrameStitcher {
    public static let minimumOverlap = 8

    /// Build a signature from 8-bit grayscale pixels (one byte per pixel).
    public static func signature(gray: [UInt8], width: Int, height: Int) -> RowSignature {
        guard width > 0, height > 0, gray.count >= width * height else {
            return RowSignature(width: width, height: height, rows: [])
        }
        var rows: [UInt64] = []
        rows.reserveCapacity(height)
        let sampleCount = 16
        for y in 0..<height {
            var packed: UInt64 = 0
            let base = y * width
            for s in 0..<sampleCount {
                let x = sampleCount == 1 ? 0 : (s * (width - 1)) / (sampleCount - 1)
                let value = UInt64(gray[base + x] >> 4) // 0...15
                packed |= value << UInt64(s * 4)
            }
            rows.append(packed)
        }
        return RowSignature(width: width, height: height, rows: rows)
    }

    /// Finds how many rows at the top of `new` already exist at the bottom of
    /// `existing`. Returns 0 when the frames do not overlap confidently.
    public static func findOverlap(existing: RowSignature, new: RowSignature) -> Int {
        let maxOverlap = min(existing.height, new.height)
        guard maxOverlap >= minimumOverlap else { return 0 }

        let lowerBound = max(minimumOverlap, Int(Double(new.height) * 0.08))
        guard lowerBound <= maxOverlap else { return 0 }

        // Prefer the largest plausible overlap: a scrolling step is normally
        // smaller than the selection height, and a too-small overlap would
        // duplicate content.
        for overlap in stride(from: maxOverlap, through: lowerBound, by: -1) {
            // A full-height match is only believable when the rows are
            // actually identical. A static frame around moving content can
            // otherwise look like a perfect overlap and hide every later
            // frame.
            if overlap == maxOverlap {
                let a = existing.rows[(existing.height - overlap)...]
                let b = new.rows[0..<overlap]
                if !a.elementsEqual(b) { continue }
            }
            let sampleStep = max(1, overlap / 32)
            var totalDistance = 0
            var samples = 0
            var y = 0
            while y < overlap {
                let a = existing.rows[existing.height - overlap + y]
                let b = new.rows[y]
                totalDistance += rowDistance(a, b)
                samples += 1
                y += sampleStep
            }
            guard samples >= 6 else { continue }
            let average = Double(totalDistance) / Double(samples) / 16.0
            if average <= 0.055 {
                return overlap
            }
        }
        return 0
    }

    /// Given frame heights and the overlap between each consecutive pair,
    /// returns each frame's top offset and the stitched height.
    public static func plan(heights: [Int], overlaps: [Int]) -> StitchPlan {
        guard let first = heights.first else {
            return StitchPlan(offsets: [], overlaps: [], totalHeight: 0)
        }
        var offsets = [0]
        var total = first
        for index in 1..<heights.count {
            let overlap = index - 1 < overlaps.count
                ? max(0, min(overlaps[index - 1], min(heights[index], heights[index - 1])))
                : 0
            offsets.append(total - overlap)
            total += heights[index] - overlap
        }
        return StitchPlan(offsets: offsets, overlaps: overlaps, totalHeight: total)
    }

    /// Convenience for the app: compute the plan directly from signatures.
    public static func plan(signatures: [RowSignature]) -> StitchPlan {
        guard !signatures.isEmpty else {
            return StitchPlan(offsets: [], overlaps: [], totalHeight: 0)
        }
        var overlaps: [Int] = []
        if signatures.count > 1 {
            for index in 1..<signatures.count {
                overlaps.append(findOverlap(existing: signatures[index - 1], new: signatures[index]))
            }
        }
        return plan(heights: signatures.map(\.height), overlaps: overlaps)
    }

    private static func rowDistance(_ a: UInt64, _ b: UInt64) -> Int {
        var differentNibbles = 0
        var xor = a ^ b
        for _ in 0..<16 {
            if xor & 0xF != 0 { differentNibbles += 1 }
            xor >>= 4
        }
        return differentNibbles
    }
}
