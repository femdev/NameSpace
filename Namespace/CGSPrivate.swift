// Private API surface. Declarations for the undocumented CoreGraphics/SkyLight (CGS)
// symbols used to enumerate and query Spaces, plus a dlopen shim for the (removed in
// macOS 26) CoreDock space-switch. These symbols are NOT public API — they have been
// stable for years but a future macOS could change or remove them. The riskiest file
// in the project; change with care.

import Foundation
import CoreGraphics

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray

enum CoreDock {
    typealias SwitchToSpaceFn = @convention(c) (UInt64) -> Void

    static let switchToSpace: SwitchToSpaceFn? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/CoreDock.framework/CoreDock",
            RTLD_NOW
        ) else { return nil }
        guard let sym = dlsym(handle, "CoreDockSwitchToSpace") else { return nil }
        return unsafeBitCast(sym, to: SwitchToSpaceFn.self)
    }()
}
