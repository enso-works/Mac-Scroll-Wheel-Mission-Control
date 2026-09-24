import AppKit
import ApplicationServices

/// Watches the middle mouse button through a CGEventTap and turns clicks and drags into actions.
final class GestureEngine: ObservableObject {
    static let shared = GestureEngine()

    /// Tags events we post ourselves so the tap ignores them.
    static let syntheticEventMarker: Int64 = 0x5357_4D43

    private static let middleButton: Int64 = 2

    @Published private(set) var isTrusted = AXIsProcessTrusted()

    private let settings = AppSettings.shared
    private var tap: CFMachPort?
    private var pollTimer: Timer?

    private var gestureStart: CGPoint = .zero
    private var didSwitch = false
    private var passThrough = false

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
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            passThrough = !settings.isEnabled || settings.isExcluded(frontmost)
        }
        if passThrough { return pass }

        switch type {
        case .otherMouseDown:
            gestureStart = event.location
            didSwitch = false
        case .otherMouseDragged:
            // One switch per press; release and drag again to move further.
            if !didSwitch { didSwitch = switchIfDragged(to: event.location) }
        case .otherMouseUp:
            if !didSwitch && !switchIfDragged(to: event.location) {
                performClickAction(at: event.location)
            }
        default:
            return pass
        }
        // Swallow the original event so apps don't also react to it.
        return nil
    }

    /// Switches desktop when the pointer has moved far enough horizontally. Returns whether it did.
    private func switchIfDragged(to location: CGPoint) -> Bool {
        let dx = location.x - gestureStart.x
        guard abs(dx) >= settings.dragDistance else { return false }
        let draggedRight = dx > 0
        SystemActions.switchSpace(right: settings.naturalDirection ? !draggedRight : draggedRight)
        return true
    }

    private func performClickAction(at location: CGPoint) {
        switch settings.clickAction {
        case .missionControl: SystemActions.openMissionControl()
        case .appWindows: SystemActions.showAppWindows()
        case .middleClick: SystemActions.postMiddleClick(at: location)
        }
    }
}
