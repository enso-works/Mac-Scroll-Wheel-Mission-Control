import SwiftUI
import UniformTypeIdentifiers

/// Hosts the settings view in a plain AppKit window, which a menu bar app can bring to front reliably.
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            window.title = "Scroll Wheel Mission Control"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    /// Grow to fit all content instead of scrolling. Used when rendering README screenshots.
    var fitsContent = false

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var engine = GestureEngine.shared
    @State private var launchAtLogin = LoginItem.isEnabled

    private let repoURL = URL(string: "https://github.com/enso-works/Mac-Scroll-Wheel-Mission-Control")!
    private let websiteURL = URL(string: "https://scrollwheelmissioncontrol.bavrk.com")!

    /// Tall enough for most sections, short enough for a 13-inch screen; the form scrolls beyond it.
    private var windowHeight: CGFloat {
        min(760, (NSScreen.main?.visibleFrame.height ?? 800) - 60)
    }

    var body: some View {
        form
            .frame(width: 500, height: fitsContent ? nil : windowHeight)
            .fixedSize(horizontal: false, vertical: fitsContent)
            .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    private var form: some View {
        Form {
            Section {
                HeaderRow()
                PermissionRow(isTrusted: engine.isTrusted)
            }

            Section("General") {
                Toggle("Enable scroll wheel gestures", isOn: $settings.isEnabled)
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        LoginItem.setEnabled(newValue)
                        launchAtLogin = LoginItem.isEnabled
                    }
                ))
            }

            Section {
                Picker("Drag left / right", selection: $settings.naturalDirection) {
                    Text("Switch desktop (natural)").tag(true)
                    Text("Switch desktop (standard)").tag(false)
                }
                Picker("Drag up", selection: $settings.dragUpAction) {
                    ForEach(VerticalAction.allCases) { Text($0.title).tag($0) }
                }
                Picker("Drag down", selection: $settings.dragDownAction) {
                    ForEach(VerticalAction.allCases) { Text($0.title).tag($0) }
                }
                Picker("Wheel click", selection: $settings.clickAction) {
                    ForEach(ClickAction.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Drag distance") {
                    HStack {
                        Slider(value: $settings.dragDistance, in: AppSettings.dragDistanceRange, step: 5)
                        Text("\(Int(settings.dragDistance)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            } header: {
                Text("Gestures")
            } footer: {
                Text(settings.naturalDirection
                     ? "Hold the wheel and drag. Natural: drag right to go to the desktop on the left, like pushing the screen aside. One action per drag."
                     : "Hold the wheel and drag. Standard: drag right to go to the desktop on the right. One action per drag.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                AppRulesList(settings: settings)
            } header: {
                Text("App rules")
            } footer: {
                Text("Off: the app gets the middle button untouched, e.g. for orbiting in Blender. Gestures only: dragging still works, but a wheel click is always a normal middle click, whatever Wheel click is set to.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Link("Website", destination: websiteURL)
                    Link("GitHub", destination: repoURL)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct HeaderRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scroll Wheel Mission Control")
                    .font(.title3.weight(.semibold))
                Text("Switch desktops by dragging with the scroll wheel held down.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PermissionRow: View {
    let isTrusted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(isTrusted ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isTrusted ? "Accessibility access granted" : "Accessibility access needed")
                        .font(.headline)
                    Text(isTrusted
                         ? "Gestures are active."
                         : "Needed to read the scroll wheel button. Nothing is recorded or sent anywhere.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if !isTrusted {
                Text("In Privacy & Security > Accessibility, turn this on:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                AccessibilityToggleHint()
                HStack {
                    Spacer()
                    Button("Open Settings") {
                        AccessibilityPermission.requestAccess()
                        AccessibilityPermission.openSettings()
                    }
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

/// A picture of the row users need to switch on in System Settings.
private struct AccessibilityToggleHint: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 26, height: 26)
            Text("Scroll Wheel Mission Control")
            Spacer()
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 38, height: 22)
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(.white)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.25)))
        .accessibilityHidden(true)
    }
}

private struct AppRulesList: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        if settings.appRules.isEmpty {
            Text("No app rules. Gestures work the same in every app.")
                .foregroundStyle(.secondary)
        }
        ForEach($settings.appRules) { $rule in
            HStack(spacing: 10) {
                Image(nsImage: AppInfo.icon(for: rule.bundleID))
                    .resizable()
                    .frame(width: 22, height: 22)
                Text(AppInfo.name(for: rule.bundleID))
                    .lineLimit(1)
                Spacer()
                Picker("Mode for \(AppInfo.name(for: rule.bundleID))", selection: $rule.mode) {
                    ForEach(AppMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                Button {
                    settings.appRules.removeAll { $0.bundleID == rule.bundleID }
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove")
            }
        }
        HStack {
            Spacer()
            Menu("Add App") {
                ForEach(runningApps, id: \.bundleIdentifier) { app in
                    Button(app.localizedName ?? app.bundleIdentifier ?? "") { add(app.bundleIdentifier) }
                }
                if !runningApps.isEmpty { Divider() }
                Button("Choose from Applications...") { chooseApp() }
            }
            .fixedSize()
        }
    }

    /// Running apps with a Dock icon that don't have a rule yet.
    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .filter { !settings.hasRule(for: $0.bundleIdentifier) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func add(_ bundleID: String?) {
        guard let bundleID, !settings.hasRule(for: bundleID) else { return }
        settings.appRules.append(AppRule(bundleID: bundleID, mode: .off))
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        add(Bundle(url: url)?.bundleIdentifier)
    }
}

private enum AppInfo {
    static func name(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    static func icon(for bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSWorkspace.shared.icon(for: .application)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
