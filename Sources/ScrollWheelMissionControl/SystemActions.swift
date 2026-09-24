import AppKit

/// Triggers macOS Spaces and Mission Control features by posting their default shortcuts.
enum SystemActions {
    private enum KeyCode {
        static let left: CGKeyCode = 123
        static let right: CGKeyCode = 124
        static let down: CGKeyCode = 125
    }

    /// Posts Ctrl+Left / Ctrl+Right ("Move left/right a space").
    static func switchSpace(right: Bool) {
        postShortcut(right ? KeyCode.right : KeyCode.left)
    }

    static func openMissionControl() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
    }

    /// Posts Ctrl+Down ("Application windows").
    static func showAppWindows() {
        postShortcut(KeyCode.down)
    }

    /// Re-creates a plain middle click at `location`, tagged so the event tap lets it through.
    static func postMiddleClick(at location: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let event = CGEvent(mouseEventSource: src, mouseType: type,
                                      mouseCursorPosition: location, mouseButton: .center) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: GestureEngine.syntheticEventMarker)
            event.post(tap: .cghidEventTap)
        }
    }

    private static func postShortcut(_ key: CGKeyCode) {
        // Arrow-key hotkeys are registered with Ctrl + Fn, so the Fn flag is required to match.
        let flags: CGEventFlags = [.maskControl, .maskSecondaryFn]
        let src = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: isDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }
}
