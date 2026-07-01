// Persistence for Space names. A UUID→name dictionary in UserDefaults, plus the
// fallback-name and display-name rules. Pure logic, fully unit-tested.

import Foundation

final class SpaceStore {
    private let defaults: UserDefaults
    private let key = "spaceNamesByUUID"

    /// The persistence store defaults to the shared `UserDefaults`. Tests inject an
    /// isolated suite so they don't read or clobber the real user's saved names.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func name(forUUID uuid: String) -> String? {
        all()[uuid]
    }

    func setName(_ name: String?, forUUID uuid: String) {
        var dict = all()
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            dict[uuid] = name
        } else {
            dict.removeValue(forKey: uuid)
        }
        defaults.set(dict, forKey: key)
    }

    func all() -> [String: String] {
        defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func fallbackName(forUUID uuid: String) -> String {
        "Space " + String(uuid.suffix(4))
    }

    func displayName(forUUID uuid: String) -> String {
        name(forUUID: uuid) ?? fallbackName(forUUID: uuid)
    }
}
