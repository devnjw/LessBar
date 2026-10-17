import XCTest
@testable import LessBar

final class UsageGuideAnimationTests: XCTestCase {
    func testPlacementCompletesDragHideRevealAndReturnBeforeLooping() {
        let placed = UsageGuideAnimation.arrangement(at: 2.8)
        XCTAssertEqual(placed.placement, 1)
        XCTAssertTrue(placed.editing)
        XCTAssertEqual(placed.hidden, 0)
        let hidden = UsageGuideAnimation.arrangement(at: 4.8)
        XCTAssertEqual(hidden.placement, 1)
        XCTAssertEqual(hidden.hidden, 1)
        XCTAssertFalse(hidden.editing)
        let expanded = UsageGuideAnimation.arrangement(at: 6.2)
        XCTAssertEqual(expanded.placement, 1)
        XCTAssertEqual(expanded.hidden, 0)
        let returned = UsageGuideAnimation.arrangement(at: 9.4)
        XCTAssertEqual(returned.placement, 0)
        XCTAssertTrue(returned.editing)
        XCTAssertEqual(returned.hidden, 0)
    }

    func testPlacementSeamHasIdenticalRestingFrames() {
        let duration = UsageGuideAnimation.arrangementDuration
        let initial = UsageGuideAnimation.arrangement(at: 0)
        for time in [duration - 0.01, duration, duration + 0.01, duration * 100] {
            XCTAssertEqual(UsageGuideAnimation.arrangement(at: time), initial)
        }
    }

    func testEveryRevealMethodReturnsToHiddenAndHasNoSeam() {
        let duration = UsageGuideAnimation.revealDuration
        for method in UsageGuideAnimation.Method.allCases {
            let initial = UsageGuideAnimation.reveal(at: 0, method: method)
            XCTAssertEqual(initial.hidden, 1)
            XCTAssertEqual(UsageGuideAnimation.reveal(at: 2.4, method: method).hidden, 0)
            XCTAssertEqual(UsageGuideAnimation.reveal(at: 6, method: method).hidden, 1)
            for time in [duration - 0.01, duration, duration + 0.01, duration * 100] {
                XCTAssertEqual(UsageGuideAnimation.reveal(at: time, method: method), initial)
            }
            let activation = UsageGuideAnimation.reveal(at: 1.38, method: method)
            XCTAssertEqual(activation.click > 0, method != .hover)
        }
    }
}
