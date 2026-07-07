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

    func testSummaryAllGoodOnlyWhenBothGrantedAndRearrangeOff() {
        XCTAssertTrue(PermissionsSummary(accessibility: .granted, automation: .granted, autoRearrangeOn: false).allGood)
        XCTAssertFalse(PermissionsSummary(accessibility: .granted, automation: .denied, autoRearrangeOn: false).allGood)
        XCTAssertFalse(PermissionsSummary(accessibility: .notDetermined, automation: .granted, autoRearrangeOn: false).allGood)
        XCTAssertFalse(PermissionsSummary(accessibility: .denied, automation: .denied, autoRearrangeOn: false).allGood)
    }

    func testAutoRearrangeOnBreaksAllGoodEvenWithBothPermissions() {
        // Permissions granted but auto-rearrange still on -> not good to go.
        let s = PermissionsSummary(accessibility: .granted, automation: .granted, autoRearrangeOn: true)
        XCTAssertFalse(s.allGood)
        XCTAssertTrue(s.needsAttention)
    }

    func testNeedsAttentionIsInverseOfAllGood() {
        XCTAssertFalse(PermissionsSummary(accessibility: .granted, automation: .granted, autoRearrangeOn: false).needsAttention)
        XCTAssertTrue(PermissionsSummary(accessibility: .granted, automation: .notDetermined, autoRearrangeOn: false).needsAttention)
    }
}
