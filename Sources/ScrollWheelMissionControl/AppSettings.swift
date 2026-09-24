import Foundation

/// What a plain scroll wheel click (no drag) does.
enum ClickAction: String, CaseIterable, Identifiable {
    case middleClick
    case missionControl
    case appWindows
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missionControl: return "Open Mission Control"
        case .appWindows: return "Show app windows (App Exposé)"
        case .middleClick: return "Normal middle click"
        case .none: return "Nothing"
        }
    }
}

/// What a vertical drag does.
enum VerticalAction: String, CaseIterable, Identifiable {
    case none
    case missionControl
    case appWindows
    case showDesktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Nothing"
        case .missionControl: return "Mission Control"
        case .appWindows: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        }
    }
}

/// How the middle button behaves while a specific app is frontmost.
enum AppMode: String, CaseIterable, Identifiable, Codable {
    /// The app gets every middle-button event untouched (e.g. Blender).
    case off
    /// Drags still trigger gestures, but a plain click reaches the app as a normal middle click.
    case gesturesOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Off"
        case .gesturesOnly: return "Gestures only"
        }
    }
}

struct AppRule: Codable, Equatable, Identifiable {
    var bundleID: String
    var mode: AppMode

    var id: String { bundleID }
}

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let dragDistanceRange: ClosedRange<Double> = 10...150

    private enum Key {
        static let isEnabled = "isEnabled"
        static let naturalDirection = "naturalDirection"
        static let dragDistance = "dragDistance"
        static let clickAction = "clickAction"
        static let dragUpAction = "dragUpAction"
        static let dragDownAction = "dragDownAction"
        static let appRules = "appRules"
        /// Pre-1.1 list of apps that were fully excluded; migrated into `appRules`.
        static let legacyExcludedBundleIDs = "excludedBundleIDs"
    }

    private let defaults = UserDefaults.standard

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    /// Natural: drag right to reveal the desktop on the left, like pushing the screen aside.
    @Published var naturalDirection: Bool {
        didSet { defaults.set(naturalDirection, forKey: Key.naturalDirection) }
    }

    /// Distance in points the pointer must travel before a drag counts.
    @Published var dragDistance: Double {
        didSet { defaults.set(dragDistance, forKey: Key.dragDistance) }
    }

    @Published var clickAction: ClickAction {
        didSet { defaults.set(clickAction.rawValue, forKey: Key.clickAction) }
    }

    @Published var dragUpAction: VerticalAction {
        didSet { defaults.set(dragUpAction.rawValue, forKey: Key.dragUpAction) }
    }

    @Published var dragDownAction: VerticalAction {
        didSet { defaults.set(dragDownAction.rawValue, forKey: Key.dragDownAction) }
    }

    @Published var appRules: [AppRule] {
        didSet { defaults.set(try? JSONEncoder().encode(appRules), forKey: Key.appRules) }
    }

    private init() {
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.naturalDirection: true,
            Key.dragDistance: 30.0,
            // Drag up already opens Mission Control, so a plain click stays a normal middle click.
            Key.clickAction: ClickAction.middleClick.rawValue,
            Key.dragUpAction: VerticalAction.missionControl.rawValue,
            Key.dragDownAction: VerticalAction.appWindows.rawValue,
        ])
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        naturalDirection = defaults.bool(forKey: Key.naturalDirection)
        dragDistance = defaults.double(forKey: Key.dragDistance)
        clickAction = ClickAction(rawValue: defaults.string(forKey: Key.clickAction) ?? "") ?? .middleClick
        dragUpAction = VerticalAction(rawValue: defaults.string(forKey: Key.dragUpAction) ?? "") ?? .missionControl
        dragDownAction = VerticalAction(rawValue: defaults.string(forKey: Key.dragDownAction) ?? "") ?? .appWindows
        appRules = Self.loadAppRules(from: defaults)
    }

    private static func loadAppRules(from defaults: UserDefaults) -> [AppRule] {
        if let data = defaults.data(forKey: Key.appRules),
           let rules = try? JSONDecoder().decode([AppRule].self, from: data) {
            return rules
        }
        // First launch of 1.1: carry over the old exclude list, or start with Blender.
        let legacy = defaults.stringArray(forKey: Key.legacyExcludedBundleIDs) ?? ["org.blenderfoundation.blender"]
        return legacy.map { AppRule(bundleID: $0, mode: .off) }
    }

    func mode(for bundleID: String?) -> AppMode? {
        guard let bundleID else { return nil }
        return appRules.first { $0.bundleID == bundleID }?.mode
    }

    func hasRule(for bundleID: String?) -> Bool {
        mode(for: bundleID) != nil
    }
}
