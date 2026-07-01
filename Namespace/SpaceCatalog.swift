// Reads the Space topology from CGS: the ordered user Spaces for the current display,
// and the current Space's id64 / UUID. `parseSpaces` converts the raw CGS dictionary
// into `[Space]` and is the unit-tested seam (the live CGS calls are not testable).
// Space identity: UUID is stable across reorder (used for naming); id64 is the live
// handle used for switching.

import Foundation
import AppKit

struct Space: Equatable {
    let uuid: String
    let id64: UInt64
}

enum SpaceCatalog {
    static func currentDisplaySpaces() -> [Space] {
        let cid = CGSMainConnectionID()
        let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]] ?? []
        let mainDisplayUUID = currentMainDisplayUUID()
        let dict: [String: Any] = displays.first {
            ($0["Display Identifier"] as? String) == mainDisplayUUID
        } ?? displays.first ?? [:]
        return parseSpaces(from: dict)
    }

    static func currentSpaceID() -> UInt64 {
        CGSGetActiveSpace(CGSMainConnectionID())
    }

    static func currentSpaceUUID() -> String? {
        let id = currentSpaceID()
        return currentDisplaySpaces().first(where: { $0.id64 == id })?.uuid
    }

    // Internal (not private) so unit tests can exercise it via `@testable import`.
    static func parseSpaces(from displayDict: [String: Any]) -> [Space] {
        guard let raw = displayDict["Spaces"] as? [[String: Any]] else { return [] }
        return raw.compactMap { dict -> Space? in
            let type = (dict["type"] as? Int) ?? 0
            // type 0 = user space; skip fullscreen/tiled (type 4)
            guard type == 0 else { return nil }
            guard let uuid = dict["uuid"] as? String else { return nil }
            let id64: UInt64
            if let v = dict["id64"] as? UInt64 {
                id64 = v
            } else if let v = dict["ManagedSpaceID"] as? UInt64 {
                id64 = v
            } else if let n = dict["id64"] as? NSNumber {
                id64 = n.uint64Value
            } else if let n = dict["ManagedSpaceID"] as? NSNumber {
                id64 = n.uint64Value
            } else {
                return nil
            }
            return Space(uuid: uuid, id64: id64)
        }
    }

    private static func currentMainDisplayUUID() -> String? {
        guard let screen = NSScreen.main,
              let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        let displayID = num.uint32Value
        guard let cfUUID = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, cfUUID) as String?
    }
}
