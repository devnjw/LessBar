import ApplicationServices
import XCTest
@testable import LessBar

final class AccessibilityGeometryTests: XCTestCase {
    func testMalformedRemoteValuesNeverBecomeGeometry() {
        var point = CGPoint(x: 12, y: 8)
        var size = CGSize(width: 24, height: 30)
        let position = AXValueCreate(.cgPoint, &point)!
        let extent = AXValueCreate(.cgSize, &size)!
        XCTAssertEqual(AccessibilityGeometryReader.frame(position: position, size: extent),
            CGRect(origin: point, size: size))
        XCTAssertNil(AccessibilityGeometryReader.frame(position: "unexpected" as CFString, size: extent))
        XCTAssertNil(AccessibilityGeometryReader.frame(position: extent, size: position))
        XCTAssertNil(AccessibilityGeometryReader.frame(position: nil, size: extent))
        size.width = .infinity
        XCTAssertNil(AccessibilityGeometryReader.frame(position: position, size: AXValueCreate(.cgSize, &size)))
        size.width = -1
        XCTAssertNil(AccessibilityGeometryReader.frame(position: position, size: AXValueCreate(.cgSize, &size)))
    }

    func testPartialSnapshotCannotExposeAnUnreadMenuAsEmptySpace() {
        var reads = 0
        let result = AccessibilityGeometryReader.completeFrames(of: [1, 2, 3]) { item in
            reads += 1
            return item == 2 ? nil : CGRect(x: item * 20, y: 0, width: 20, height: 30)
        }
        XCTAssertNil(result)
        XCTAssertEqual(reads, 2, "Stop querying an unresponsive process after the first failure")
        XCTAssertNil(AccessibilityGeometryReader.completeFrames(of: Array(0...64)) { _ in
            XCTFail("Unexpectedly large remote arrays must not generate unbounded AX traffic")
            return .zero
        })
        XCTAssertNil(AccessibilityGeometryReader.completeFrames(of: [Int]()) { _ in .zero })
    }
}
