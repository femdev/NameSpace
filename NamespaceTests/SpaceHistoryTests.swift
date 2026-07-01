// Unit tests for SpaceHistory — the previous-Space tracker behind the "Back" action.

import XCTest
@testable import Namespace

final class SpaceHistoryTests: XCTestCase {
    private var history: SpaceHistory!

    override func setUp() {
        super.setUp()
        history = SpaceHistory()
    }

    func testNoBackBeforeAnyMovement() {
        XCTAssertNil(history.back)
    }

    func testNoBackAfterSingleSpaceRecorded() {
        history.record(1)
        XCTAssertNil(history.back)
        XCTAssertEqual(history.current, 1)
    }

    func testBackPointsToPreviousSpace() {
        history.record(1)
        history.record(2)
        XCTAssertEqual(history.back, 1)
        XCTAssertEqual(history.current, 2)
    }

    func testDuplicateNotificationIsIgnored() {
        history.record(1)
        history.record(2)
        history.record(2) // spurious repeat of the same active space
        XCTAssertEqual(history.back, 1)
        XCTAssertEqual(history.current, 2)
    }

    func testManualMovesAdvanceHistory() {
        history.record(1)
        history.record(2)
        history.record(3)
        XCTAssertEqual(history.current, 3)
        XCTAssertEqual(history.back, 2)
    }

    func testProgrammaticSwitchIgnoresFlyoverSpaces() {
        history.record(5)          // we're on space 5
        history.record(1)          // manually moved to 1; back = 5
        XCTAssertEqual(history.back, 5)

        // Now Back to 5, which walks 1 -> 2 -> 3 -> 4 -> 5. Only the target lands.
        history.beginProgrammaticSwitch(to: 5)
        history.record(2)
        history.record(3)
        history.record(4)
        history.record(5)
        XCTAssertEqual(history.current, 5)
        XCTAssertEqual(history.back, 1) // toggles back to where we came from
    }

    func testBackTogglesBetweenTwoSpaces() {
        history.record(10)
        history.record(20)         // current 20, back 10
        history.beginProgrammaticSwitch(to: 10)
        history.record(10)         // direct jump lands immediately
        XCTAssertEqual(history.current, 10)
        XCTAssertEqual(history.back, 20)

        history.beginProgrammaticSwitch(to: 20)
        history.record(20)
        XCTAssertEqual(history.current, 20)
        XCTAssertEqual(history.back, 10)
    }

    func testAbandonPendingSwitchResumesManualRecording() {
        history.record(1)
        history.record(2)
        history.beginProgrammaticSwitch(to: 9) // never lands (switch failed)
        history.abandonPendingSwitch()
        history.record(3)                       // a real manual move
        XCTAssertEqual(history.current, 3)
        XCTAssertEqual(history.back, 2)
    }
}
