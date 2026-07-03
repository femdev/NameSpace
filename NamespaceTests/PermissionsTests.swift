// Unit tests for the pure permission logic: the Apple-Events status-code mapping and the
// PermissionsSummary derivations. The live TCC probes and polling are not unit-testable.

import XCTest
import CoreServices
@testable import Namespace

final class PermissionsTests: XCTestCase {

    func testAutomationStatusMapping() {
        XCTAssertEqual(PermissionsMonitor.automationState(fromStatus: noErr), .granted)
        XCTAssertEqual(PermissionsMonitor.automationState(fromStatus: OSStatus(errAEEventNotPermitted)), .denied)
        XCTAssertEqual(PermissionsMonitor.automationState(fromStatus: OSStatus(errAEEventWouldRequireUserConsent)), .notDetermined)
    }

    func testUnexpectedStatusIsNotDetermined() {
        // procNotFound (System Events not running) and any other code are treated as
        // "can't prove denial" → not determined.
        XCTAssertEqual(PermissionsMonitor.automationState(fromStatus: OSStatus(procNotFound)), .notDetermined)
        XCTAssertEqual(PermissionsMonitor.automationState(fromStatus: -12345), .notDetermined)
    }

    func testSummaryAllGrantedOnlyWhenBothGranted() {
        XCTAssertTrue(PermissionsSummary(accessibility: .granted, automation: .granted).allGranted)
        XCTAssertFalse(PermissionsSummary(accessibility: .granted, automation: .denied).allGranted)
        XCTAssertFalse(PermissionsSummary(accessibility: .notDetermined, automation: .granted).allGranted)
        XCTAssertFalse(PermissionsSummary(accessibility: .denied, automation: .denied).allGranted)
    }

    func testNeedsAttentionIsInverseOfAllGranted() {
        XCTAssertFalse(PermissionsSummary(accessibility: .granted, automation: .granted).needsAttention)
        XCTAssertTrue(PermissionsSummary(accessibility: .granted, automation: .notDetermined).needsAttention)
    }
}
