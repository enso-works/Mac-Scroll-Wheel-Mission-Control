// Renders the real settings view to PNGs for the README, in light and dark mode.
// Compiled together with the app sources (minus App.swift) by scripts/render-screenshots.sh.

import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.applicationIconImage = NSImage(contentsOfFile: "Resources/AppIcon-1024.png")
app.activate(ignoringOtherApps: true)

func renderSettings(trusted: Bool, fitsContent: Bool = true, appearance: NSAppearance.Name, to path: String) {
    GestureEngine.shared.isTrusted = trusted
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(fitsContent: fitsContent)))
    window.title = "Scroll Wheel Mission Control"
    window.styleMask = [.titled, .closable]
    window.appearance = NSAppearance(named: appearance)
    window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    window.makeKeyAndOrderFront(nil)
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))

    // The theme frame includes the title bar, so the image looks like a real window.
    let view = window.contentView!.superview!
    let scale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(view.bounds.width * scale), pixelsHigh: Int(view.bounds.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    window.close()
    print("wrote \(path)")
}

for (appearance, suffix) in [(NSAppearance.Name.darkAqua, "dark"), (.aqua, "light")] {
    renderSettings(trusted: true, appearance: appearance, to: "docs/images/settings-\(suffix).png")
    renderSettings(trusted: false, appearance: appearance, to: "docs/images/permission-\(suffix).png")
    // The window as it appears on screen: capped height, rest scrolls. Used for the website hero.
    renderSettings(trusted: true, fitsContent: false, appearance: appearance, to: "docs/images/settings-window-\(suffix).png")
}
