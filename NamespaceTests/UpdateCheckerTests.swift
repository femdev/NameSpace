// Unit tests for the pure version-comparison logic behind "Check for Updates".
// The network fetch itself is not unit-tested.

import XCTest
@testable import Namespace

final class UpdateCheckerTests: XCTestCase {

    func testVersionComponentsParsesAndStripsPrefix() {
        XCTAssertEqual(UpdateChecker.versionComponents("v0.2.0"), [0, 2, 0])
        XCTAssertEqual(UpdateChecker.versionComponents("0.1"), [0, 1])
        XCTAssertEqual(UpdateChecker.versionComponents("  v1.10.3 "), [1, 10, 3])
    }

    func testVersionComponentsToleratesTrailingNonDigits() {
        XCTAssertEqual(UpdateChecker.versionComponents("0.2.0-beta"), [0, 2, 0])
        XCTAssertEqual(UpdateChecker.versionComponents("v2.0rc1"), [2, 0])
    }

    func testNewerBumpInAnyComponent() {
        XCTAssertTrue(UpdateChecker.isNewer("v0.1.1", than: "0.1.0"))
        XCTAssertTrue(UpdateChecker.isNewer("v0.2.0", than: "0.1.9"))
        XCTAssertTrue(UpdateChecker.isNewer("v1.0.0", than: "0.9.9"))
    }

    func testNotNewerWhenSameOrOlder() {
        XCTAssertFalse(UpdateChecker.isNewer("v0.1.0", than: "0.1.0"))
        XCTAssertFalse(UpdateChecker.isNewer("v0.1.0", than: "0.2.0"))
        XCTAssertFalse(UpdateChecker.isNewer("v0.1.0", than: "0.1.1"))
    }

    func testZeroPaddingAcrossDifferentComponentCounts() {
        // "0.1" vs "0.1.1": the extra .1 makes it newer.
        XCTAssertTrue(UpdateChecker.isNewer("0.1.1", than: "0.1"))
        // "0.1.0" is not newer than "0.1".
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1"))
        // "0.2" beats "0.1.9".
        XCTAssertTrue(UpdateChecker.isNewer("0.2", than: "0.1.9"))
    }
}
