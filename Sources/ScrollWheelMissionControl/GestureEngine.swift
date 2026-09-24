import AppKit
import ApplicationServices

/// Watches the middle mouse button through a CGEventTap and turns clicks and drags into actions.
final class GestureEngine: ObservableObject {
    static let shared = GestureEngine()

    /// Tags events we post ourselves so the tap ignores them.
    static let syntheticEventMarker: Int64 = 0x5357_4D43

    private static let middleButton: Int64 = 2

    #if SCREENSHOTS
    @Published var isTrusted = AXIsProcessTrusted()
    #else
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    #endif

    private let settings = AppSettings.shared
    private var tap: CFMachPort?
    private var pollTimer: Timer?

    private var gestureStart: CGPoint = .zero
    private var didAct = false
    private var passThrough = false
    /// The frontmost app keeps its plain middle click (per-app "Gestures only" mode).
    private var clickPassesThrough = false

    private init() {}

    func start() {
        refresh()
        // Accessibility can be granted or revoked at any time; keep checking.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
        if trusted && tap == nil { installTap() }
    }

    private func installTap() {
        let mask = (1 << CGEventType.otherMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDragged.rawValue)
            | (1 << CGEventType.otherMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, _ in GestureEngine.shared.handle(type: type, event: event) },
            userInfo: nil
        ) else { return }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        guard event.getIntegerValueField(.mouseEventButtonNumber) == Self.middleButton,
              event.getIntegerValueField(.eventSourceUserData) != Self.syntheticEventMarker
        else { return pass }

        // Decide once per press so a focus change mid-gesture can't split the event stream.
        if type == .otherMouseDown {
            let mode = settings.mode(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            passThrough = !settings.isEnabled || mode == .off
            clickPassesThrough = mode == .gesturesOnly
        }
        if passThrough { return pass }

        switch type {
        case .otherMouseDown:
            gestureStart = event.location
            didAct = false
        case .otherMouseDragged:
            // One action per press; release and drag again to repeat.
            if !didAct { didAct = performDragIfPastThreshold(to: event.location) }
        case .otherMouseUp:
            if !didAct && !performDragIfPastThreshold(to: event.location) {
                performClick(at: event.location)
            }
        default:
            return pass
        }
        // Swallow the original event so apps don't also react to it.
        return nil
    }

    /// Runs the drag action once the pointer has moved far enough. The dominant axis wins, so a
    /// slightly diagonal drag still counts as horizontal or vertical. Returns whether the drag counted.
    private func performDragIfPastThreshold(to location: CGPoint) -> Bool {
        let dx = location.x - gestureStart.x
        let dy = location.y - gestureStart.y
        guard max(abs(dx), abs(dy)) >= settings.dragDistance else { return false }

        if abs(dx) >= abs(dy) {
            let draggedRight = dx > 0
            SystemActions.switchSpace(right: settings.naturalDirection ? !draggedRight : draggedRight)
        } else {
            // Screen coordinates grow downward, so a negative dy is an upward drag.
            perform(dy < 0 ? settings.dragUpAction : settings.dragDownAction)
        }
        // A vertical drag set to "Nothing" still counts, so releasing doesn't fire a click.
        return true
    }

    private func perform(_ action: VerticalAction) {
        switch action {
        case .none: break
        case .missionControl: SystemActions.openMissionControl()
        case .appWindows: SystemActions.showAppWindows()
        case .showDesktop: SystemActions.showDesktop()
        }
    }

    private func performClick(at location: CGPoint) {
        if clickPassesThrough {
            SystemActions.postMiddleClick(at: location)
            return
        }
        switch settings.clickAction {
        case .missionControl: SystemActions.openMissionControl()
        case .appWindows: SystemActions.showAppWindows()
        case .middleClick: SystemActions.postMiddleClick(at: location)
        case .none: break
        }
    }
}
