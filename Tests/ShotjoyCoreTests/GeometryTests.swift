import CoreGraphics
import XCTest
@testable import ShotjoyCore

final class GeometryTests: XCTestCase {
    func testNormalizedRectFromAnyDragDirection() {
        let rect = SelectionGeometry.normalized(
            from: CGPoint(x: 120, y: 90),
            to: CGPoint(x: 20, y: 10)
        )
        XCTAssertEqual(rect, CGRect(x: 20, y: 10, width: 100, height: 80))
    }

    func testHandleHitTestPrefersCorners() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 50)
        XCTAssertEqual(
            SelectionGeometry.handle(at: CGPoint(x: 10, y: 10), in: rect),
            .topLeft
        )
        XCTAssertEqual(
            SelectionGeometry.handle(at: CGPoint(x: 60, y: 10), in: rect),
            .top
        )
        XCTAssertNil(SelectionGeometry.handle(at: CGPoint(x: 60, y: 35), in: rect))
    }

    func testResizeKeepsMinimumSize() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
        let resized = SelectionGeometry.resized(
            rect,
            handle: .right,
            to: CGPoint(x: 20, y: 50),
            minSize: 10,
            within: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        XCTAssertEqual(resized.width, 10)
        XCTAssertEqual(resized.minX, 10)
    }

    func testMoveClampsToCanvas() {
        let rect = CGRect(x: 10, y: 10, width: 100, height: 100)
        let moved = SelectionGeometry.moved(
            rect,
            by: CGPoint(x: -500, y: 500),
            within: CGRect(x: 0, y: 0, width: 300, height: 300)
        )
        XCTAssertEqual(moved.minX, 0)
        XCTAssertEqual(moved.maxY, 300)
        XCTAssertEqual(moved.size, rect.size)
    }

    func testQuartzConversionRoundTrips() {
        let mainHeight: CGFloat = 1080
        let cocoa = CGRect(x: 100, y: 200, width: 300, height: 400)
        let quartz = GlobalCoordinates.cocoaToQuartz(cocoa, mainScreenHeight: mainHeight)
        XCTAssertEqual(quartz, CGRect(x: 100, y: 480, width: 300, height: 400))
        XCTAssertEqual(
            GlobalCoordinates.quartzToCocoa(quartz, mainScreenHeight: mainHeight),
            cocoa
        )
    }

    func testAspectFit() {
        let scale = RectMath.aspectFitScale(
            CGRect(x: 0, y: 0, width: 100, height: 200),
            in: CGRect(x: 0, y: 0, width: 300, height: 300)
        )
        XCTAssertEqual(scale, 1.5, accuracy: 0.0001)
    }
}
