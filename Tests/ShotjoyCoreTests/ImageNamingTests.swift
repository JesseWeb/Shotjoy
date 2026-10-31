import Foundation
import XCTest
@testable import ShotjoyCore

final class ImageNamingTests: XCTestCase {
    func testFileNameUsesStableFormat() {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 31
        components.hour = 15
        components.minute = 4
        components.second = 9
        let date = Calendar(identifier: .gregorian).date(from: components)!
        let name = ImageNaming.fileName(
            date: date,
            prefix: "Shotjoy",
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )
        XCTAssertEqual(name, "Shotjoy 2026-10-31 15.04.09.png")
    }

    func testUniqueURLAddsSuffix() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShotjoyNaming-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = ImageNaming.uniqueURL(directory: directory, date: date)
        FileManager.default.createFile(atPath: first.path, contents: Data())
        let second = ImageNaming.uniqueURL(directory: directory, date: date)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(second.lastPathComponent.contains("-2.png"))
    }
}
