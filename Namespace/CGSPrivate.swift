// Private API surface. Declarations for the undocumented CoreGraphics/SkyLight (CGS)
// symbols used to enumerate and query Spaces. These are NOT public API — they have been
// stable for years but a future macOS could change or remove them. The riskiest file in
// the project; change with care.

import Foundation
import CoreGraphics

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: Int32) -> UInt64

@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray
