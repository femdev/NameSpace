// Unit tests for SpaceCatalog.parseSpaces — the pure seam that turns a raw CGS
// managed-display dictionary into an ordered [Space]. The live CGS calls around it
// are not unit-testable; this covers the parsing/filtering rules.

import XCTest
@testable import Namespace

final class SpaceCatalogTests: XCTestCase {
    private func display(_ spaces: [[String: Any]]) -> [String: Any] {
        ["Spaces": spaces]
    }

    func testParsesUserSpaceWithId64() {
        let dict = display([["type": 0, "uuid": "UUID-A", "id64": UInt64(101)]])
        XCTAssertEqual(SpaceCatalog.parseSpaces(from: dict), [Space(uuid: "UUID-A", id64: 101)])
    }

    func testSkipsFullscreenTiledType4() {
        let dict = display([
            ["type": 0, "uuid": "UUID-A", "id64": UInt64(101)],
            ["type": 4, "uuid": "UUID-FS", "id64": UInt64(102)],
            ["type": 0, "uuid": "UUID-B", "id64": UInt64(103)]
        ])
        XCTAssertEqual(
            SpaceCatalog.parseSpaces(from: dict),
            [Space(uuid: "UUID-A", id64: 101), Space(uuid: "UUID-B", id64: 103)]
        )
    }

    func testPreservesOrder() {
        let dict = display([
            ["type": 0, "uuid": "UUID-C", "id64": UInt64(3)],
            ["type": 0, "uuid": "UUID-A", "id64": UInt64(1)],
            ["type": 0, "uuid": "UUID-B", "id64": UInt64(2)]
        ])
        XCTAssertEqual(
            SpaceCatalog.parseSpaces(from: dict).map(\.uuid),
            ["UUID-C", "UUID-A", "UUID-B"]
        )
    }

    func testFallsBackToManagedSpaceIDWhenId64Absent() {
        let dict = display([["type": 0, "uuid": "UUID-A", "ManagedSpaceID": UInt64(77)]])
        XCTAssertEqual(SpaceCatalog.parseSpaces(from: dict), [Space(uuid: "UUID-A", id64: 77)])
    }

    func testAcceptsNSNumberEncodedIdentifiers() {
        let dict = display([["type": 0, "uuid": "UUID-A", "id64": NSNumber(value: UInt64(999))]])
        XCTAssertEqual(SpaceCatalog.parseSpaces(from: dict), [Space(uuid: "UUID-A", id64: 999)])
    }

    func testDefaultsMissingTypeToUserSpace() {
        // A dict with no "type" key is treated as type 0 (user space).
        let dict = display([["uuid": "UUID-A", "id64": UInt64(5)]])
        XCTAssertEqual(SpaceCatalog.parseSpaces(from: dict), [Space(uuid: "UUID-A", id64: 5)])
    }

    func testSkipsEntriesMissingUUID() {
        let dict = display([
            ["type": 0, "id64": UInt64(101)],
            ["type": 0, "uuid": "UUID-B", "id64": UInt64(103)]
        ])
        XCTAssertEqual(SpaceCatalog.parseSpaces(from: dict), [Space(uuid: "UUID-B", id64: 103)])
    }

    func testSkipsEntriesWithNoUsableIdentifier() {
        let dict = display([["type": 0, "uuid": "UUID-A"]])
        XCTAssertTrue(SpaceCatalog.parseSpaces(from: dict).isEmpty)
    }

    func testReturnsEmptyWhenNoSpacesKey() {
        XCTAssertTrue(SpaceCatalog.parseSpaces(from: [:]).isEmpty)
    }
}
