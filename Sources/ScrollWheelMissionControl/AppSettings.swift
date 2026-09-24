import Foundation

/// What a plain scroll wheel click (no drag) does.
enum ClickAction: String, CaseIterable, Identifiable {
    case missionControl
    case appWindows
    case middleClick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missionControl: return "Open Mission Control"
        case .appWindows: return "Show app windows (App Exposé)"
        case .middleClick: return "Normal middle click"
        }
    }
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
        static let excludedBundleIDs = "excludedBundleIDs"
    }

    private let defaults = UserDefaults.standard

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    /// Natural: drag right to reveal the desktop on the left, like pushing the screen aside.
    @Published var naturalDirection: Bool {
        didSet { defaults.set(naturalDirection, forKey: Key.naturalDirection) }
    }

    /// Horizontal distance in points the pointer must travel before a drag counts.
    @Published var dragDistance: Double {
        didSet { defaults.set(dragDistance, forKey: Key.dragDistance) }
    }

    @Published var clickAction: ClickAction {
        didSet { defaults.set(clickAction.rawValue, forKey: Key.clickAction) }
    }

    /// Apps that keep normal middle-button behavior while frontmost.
    @Published var excludedBundleIDs: [String] {
        didSet { defaults.set(excludedBundleIDs, forKey: Key.excludedBundleIDs) }
    }

    private init() {
        defaults.register(defaults: [
            Key.isEnabled: true,
            Key.naturalDirection: true,
            Key.dragDistance: 30.0,
            Key.clickAction: ClickAction.missionControl.rawValue,
            Key.excludedBundleIDs: ["org.blenderfoundation.blender"],
        ])
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        naturalDirection = defaults.bool(forKey: Key.naturalDirection)
        dragDistance = defaults.double(forKey: Key.dragDistance)
        clickAction = ClickAction(rawValue: defaults.string(forKey: Key.clickAction) ?? "") ?? .missionControl
        excludedBundleIDs = defaults.stringArray(forKey: Key.excludedBundleIDs) ?? []
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedBundleIDs.contains(bundleID)
    }
}
