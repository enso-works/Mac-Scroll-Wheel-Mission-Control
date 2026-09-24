import SwiftUI

@main
struct ScrollWheelMissionControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = GestureEngine.shared
    @ObservedObject private var updates = UpdateChecker.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent(settings: settings, engine: engine, updates: updates)
        } label: {
            Image(systemName: settings.isEnabled ? "rectangle.split.3x1.fill" : "rectangle.split.3x1")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hasLaunchedKey = "hasLaunchedBefore"

    func applicationDidFinishLaunching(_ notification: Notification) {
        GestureEngine.shared.start()
        UpdateChecker.shared.startAutomaticChecks()

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
    @ObservedObject var updates: UpdateChecker

    var body: some View {
        if let update = updates.availableUpdate {
            Button("Update Available: Version \(update.version)...") { NSWorkspace.shared.open(update.url) }
            Divider()
        }
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
        Button("Check for Updates...") {
            updates.check()
            SettingsWindow.shared.show()
        }
        Divider()
        Button("Quit Scroll Wheel Mission Control") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
