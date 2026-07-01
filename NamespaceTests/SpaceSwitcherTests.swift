// Unit tests for the pure key-mapping / walk-math helpers in SpaceSwitcher.
// The AppleScript keystroke synthesis and CGS queries are not unit-testable.

import XCTest
@testable import Namespace

final class SpaceSwitcherTests: XCTestCase {

    // macOS virtual key codes for the number row 1–9. Note 5/6 (23/22) and the
    // 7/8/9 (26/28/25) are deliberately non-contiguous — that's the actual layout.
    func testDigitKeyCodesMatchNumberRowLayout() {
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(1), 18)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(2), 19)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(3), 20)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(4), 21)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(5), 23)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(6), 22)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(7), 26)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(8), 28)
        XCTAssertEqual(SpaceSwitcher.digitKeyCode(9), 25)
    }

    func testDigitKeyCodeIsNilOutsideOneThroughNine() {
        XCTAssertNil(SpaceSwitcher.digitKeyCode(0))
        XCTAssertNil(SpaceSwitcher.digitKeyCode(10))
        XCTAssertNil(SpaceSwitcher.digitKeyCode(-1))
    }

    func testWalkDeltaIsSignedDistance() {
        XCTAssertEqual(SpaceSwitcher.walkDelta(targetIdx: 5, fromIdx: 2), 3)
        XCTAssertEqual(SpaceSwitcher.walkDelta(targetIdx: 1, fromIdx: 4), -3)
        XCTAssertEqual(SpaceSwitcher.walkDelta(targetIdx: 3, fromIdx: 3), 0)
    }

    func testWalkKeyCodeIsRightArrowForwardLeftArrowBackward() {
        XCTAssertEqual(SpaceSwitcher.walkKeyCode(delta: 2), 124)   // RightArrow
        XCTAssertEqual(SpaceSwitcher.walkKeyCode(delta: -2), 123)  // LeftArrow
    }
}
