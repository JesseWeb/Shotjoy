import CoreGraphics
import XCTest
@testable import ShotDeskCore

final class AnnotationTests: XCTestCase {
    func testUndoStack() {
        var stack = AnnotationStack()
        stack.add(Annotation(kind: .rectangle, start: .zero, end: CGPoint(x: 10, y: 10)))
        stack.add(Annotation(kind: .arrow, start: .zero, end: CGPoint(x: 20, y: 20)))
        XCTAssertTrue(stack.canUndo)
        XCTAssertEqual(stack.undo()?.kind, .arrow)
        XCTAssertEqual(stack.undo()?.kind, .rectangle)
        XCTAssertNil(stack.undo())
        XCTAssertFalse(stack.canUndo)
    }

    func testBoundsIncludeLineWidth() {
        let annotation = Annotation(
            kind: .rectangle,
            start: CGPoint(x: 10, y: 20),
            end: CGPoint(x: 110, y: 70),
            lineWidth: 5
        )
        XCTAssertEqual(annotation.bounds.minX, 5)
        XCTAssertEqual(annotation.bounds.maxX, 115)
    }

    func testPenBoundsCoverAllPoints() {
        let annotation = Annotation(
            kind: .pen,
            start: CGPoint(x: 0, y: 0),
            end: .zero,
            points: [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 50, y: 10),
                CGPoint(x: 20, y: 90)
            ],
            lineWidth: 2
        )
        XCTAssertEqual(annotation.bounds.minX, -4)
        XCTAssertEqual(annotation.bounds.maxY, 94)
    }

    func testHitTestUsesTopmostAnnotation() {
        var stack = AnnotationStack()
        stack.add(Annotation(kind: .rectangle, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 50, y: 50)))
        let top = Annotation(kind: .ellipse, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 40, y: 40))
        stack.add(top)
        XCTAssertEqual(stack.hitTest(CGPoint(x: 20, y: 20))?.id, top.id)
    }
}
