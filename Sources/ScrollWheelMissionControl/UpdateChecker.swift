import AppKit

/// Opt-in, notify-only update check against the GitHub "latest release" API.
/// Sends one anonymous HTTPS request; nothing about the user or their settings is included.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    static let releasesURL = URL(string: "https://github.com/enso-works/Mac-Scroll-Wheel-Mission-Control/releases/latest")!
    private static let apiURL = URL(string: "https://api.github.com/repos/enso-works/Mac-Scroll-Wheel-Mission-Control/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    @Published private(set) var state: State = .idle

    private let settings = AppSettings.shared
    private var timer: Timer?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var availableUpdate: (version: String, url: URL)? {
        if case let .available(version, url) = state { return (version, url) }
        return nil
    }

    private init() {}

    /// Checks now if automatic checks are on and the last check is older than a day, then keeps checking hourly.
    func startAutomaticChecks() {
        checkIfDue()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.checkIfDue()
        }
    }

    private func checkIfDue() {
        guard settings.checkForUpdates else { return }
        if let last = settings.lastUpdateCheck, Date().timeIntervalSince(last) < Self.checkInterval { return }
        check()
    }

    func check() {
        guard state != .checking else { return }
        state = .checking
        var request = URLRequest(url: Self.apiURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            let release = (response as? HTTPURLResponse)?.statusCode == 200
                ? data.flatMap { try? JSONDecoder().decode(Release.self, from: $0) }
                : nil
            DispatchQueue.main.async {
                guard let self else { return }
                guard let release else {
                    self.state = .failed
                    return
                }
                self.settings.lastUpdateCheck = Date()
                let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.state = Self.isVersion(latest, newerThan: Self.currentVersion)
                    ? .available(version: latest, url: release.htmlURL)
                    : .upToDate
            }
        }.resume()
    }

    /// Compares dotted numeric versions, e.g. "1.10.0" > "1.9.2".
    static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
