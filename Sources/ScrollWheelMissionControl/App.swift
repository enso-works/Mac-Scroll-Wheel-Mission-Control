import SwiftUI

@main
struct ScrollWheelMissionControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = GestureEngine.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings, engine: engine)
        } label: {
            Image(systemName: settings.isEnabled ? "rectangle.split.3x1.fill" : "rectangle.split.3x1")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hasLaunchedKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        GestureEngine.shared.start()

        let isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedKey)
        UserDefaults.standard.set(true, forKey: hasLaunchedKey)
        if !AXIsProcessTrusted() {
            AccessibilityPermission.requestAccess()
        }
        if isFirstLaunch || !AXIsProcessTrusted() {
            SettingsWindow.shared.show()
        }
    }

    /// Opening the app again (e.g. from Finder or Spotlight) shows its settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindow.shared.show()
        return true
    }
}

struct MenuContent: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var engine: GestureEngine

    var body: some View {
        Toggle("Enabled", isOn: $settings.isEnabled)
        if !engine.isTrusted {
            Button("Grant Accessibility Access...") {
                AccessibilityPermission.requestAccess()
                AccessibilityPermission.openSettings()
            }
        }
        Divider()
        Button("Settings...") { SettingsWindow.shared.show() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Scroll Wheel Mission Control") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
