// Unit tests for SpaceStore — the UUID→name persistence layer and its naming rules.
// Uses an isolated UserDefaults suite so the real user's saved names are never touched.

import XCTest
@testable import Namespace

final class SpaceStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var store: SpaceStore!

    override func setUp() {
        super.setUp()
        // A per-test suite name keeps runs independent. Derive it from the test name
        // (no random source is available/needed) and wipe it before use.
        suiteName = "SpaceStoreTests.\(name)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SpaceStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testUnnamedSpaceHasNoStoredName() {
        XCTAssertNil(store.name(forUUID: "UUID-A"))
    }

    func testSetAndReadName() {
        store.setName("Work", forUUID: "UUID-A")
        XCTAssertEqual(store.name(forUUID: "UUID-A"), "Work")
    }

    func testNameIsTrimmed() {
        store.setName("  Mail  ", forUUID: "UUID-A")
        XCTAssertEqual(store.name(forUUID: "UUID-A"), "Mail")
    }

    func testSettingEmptyOrWhitespaceClearsName() {
        store.setName("Work", forUUID: "UUID-A")
        store.setName("   ", forUUID: "UUID-A")
        XCTAssertNil(store.name(forUUID: "UUID-A"))
    }

    func testSettingNilClearsName() {
        store.setName("Work", forUUID: "UUID-A")
        store.setName(nil, forUUID: "UUID-A")
        XCTAssertNil(store.name(forUUID: "UUID-A"))
    }

    func testNamesAreIndependentPerUUID() {
        store.setName("Work", forUUID: "UUID-A")
        store.setName("Play", forUUID: "UUID-B")
        XCTAssertEqual(store.all(), ["UUID-A": "Work", "UUID-B": "Play"])
    }

    func testFallbackNameUsesLastFourOfUUID() {
        XCTAssertEqual(store.fallbackName(forUUID: "0123456789ABCDEF"), "Space CDEF")
    }

    func testDisplayNamePrefersStoredNameOverFallback() {
        store.setName("Work", forUUID: "0123456789ABCDEF")
        XCTAssertEqual(store.displayName(forUUID: "0123456789ABCDEF"), "Work")
    }

    func testDisplayNameFallsBackWhenUnnamed() {
        XCTAssertEqual(store.displayName(forUUID: "0123456789ABCDEF"), "Space CDEF")
    }

    func testNamesPersistAcrossStoreInstances() {
        store.setName("Work", forUUID: "UUID-A")
        let reopened = SpaceStore(defaults: defaults)
        XCTAssertEqual(reopened.name(forUUID: "UUID-A"), "Work")
    }
}
