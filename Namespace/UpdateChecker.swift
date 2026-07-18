// On-demand update check. Namespace is otherwise network-free; this is the ONE place it
// touches the network, and only when the user explicitly picks "Check for Updates…". It
// asks GitHub's Releases API for the latest published release and compares its tag to the
// running version — it downloads nothing and installs nothing. The version-comparison
// logic is pure and unit-tested; the fetch is a thin URLSession call.
//
// This works once the repository (and its releases) are public; on a private repo the API
// returns 404 and the check reports a friendly failure.

import Foundation

enum UpdateChecker {
    /// The GitHub repo that publishes releases. Update if the repo is renamed/moved.
    private static let latestReleaseAPI =
        URL(string: "https://api.github.com/repos/femdev/NameSpace/releases/latest")!
    static let releasesPage =
        URL(string: "https://github.com/femdev/NameSpace/releases")!

    enum Outcome {
        case upToDate(current: String)
        case updateAvailable(latest: String, url: URL)
        case failed(String)
    }

    // MARK: - Pure version logic (unit-tested)

    /// Numeric version components, tolerant of a leading "v" and trailing non-digits
    /// (e.g. "v0.2.0" → [0, 2, 0], "0.2.0-beta" → [0, 2, 0]).
    static func versionComponents(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noPrefix = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        return noPrefix.split(separator: ".").map { part in
            Int(part.prefix(while: { $0.isNumber })) ?? 0
        }
    }

    /// True if `latest` is a strictly newer version than `current` (component-wise,
    /// zero-padded). Pure.
    static func isNewer(_ latest: String, than current: String) -> Bool {
        let a = versionComponents(latest)
        let b = versionComponents(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - Fetch

    /// Query GitHub for the latest release and report the outcome on the main queue.
    static func checkForUpdate(currentVersion: String,
                               completion: @escaping (Outcome) -> Void) {
        let finish: (Outcome) -> Void = { outcome in
            DispatchQueue.main.async { completion(outcome) }
        }
        var request = URLRequest(url: latestReleaseAPI)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error { return finish(.failed(error.localizedDescription)) }
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 200, let data = data else {
                return finish(.failed("GitHub returned HTTP \(code). "
                                      + "The check works once the repo and its releases are public."))
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String else {
                return finish(.failed("Couldn't read the latest release."))
            }
            let url = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? releasesPage
            if isNewer(tag, than: currentVersion) {
                finish(.updateAvailable(latest: tag, url: url))
            } else {
                finish(.upToDate(current: currentVersion))
            }
        }.resume()
    }
}
