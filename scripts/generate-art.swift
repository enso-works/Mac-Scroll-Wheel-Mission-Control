// Renders the app icon and README artwork.
// Usage: swift scripts/generate-art.swift   (run from the repo root)

import AppKit

// MARK: - Palette

func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha)
}

let indigoLight = hex(0x7C8CFF)
let indigo = hex(0x5A5CF0)
let violetDark = hex(0x3B1FA3)
let night = hex(0x0E0F2B)
let nightLight = hex(0x241C63)

// MARK: - Rendering

func render(_ size: CGSize, to path: String, draw: (CGRect) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func withShadow(blur: CGFloat, offsetY: CGFloat, alpha: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: offsetY)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

func drawArrow(from start: CGPoint, to end: CGPoint, width: CGFloat, head: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: start)
    path.line(to: end)
    let angle = atan2(end.y - start.y, end.x - start.x)
    for side in [CGFloat.pi * 0.78, -CGFloat.pi * 0.78] {
        path.move(to: end)
        path.line(to: CGPoint(x: end.x + cos(angle + side) * head, y: end.y + sin(angle + side) * head))
    }
    color.setStroke()
    path.stroke()
}

func drawText(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor, maxWidth: CGFloat = 10_000) -> CGFloat {
    let style = NSMutableParagraphStyle()
    style.lineSpacing = size * 0.18
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ]
    let string = NSAttributedString(string: text, attributes: attrs)
    let bounds = string.boundingRect(with: CGSize(width: maxWidth, height: 10_000), options: [.usesLineFragmentOrigin])
    // `point` is the top-left corner of the text block.
    string.draw(with: CGRect(x: point.x, y: point.y - bounds.height, width: maxWidth, height: bounds.height),
                options: [.usesLineFragmentOrigin])
    return bounds.height
}

/// Soft radial glow that fades to fully transparent, with no visible edge.
func drawGlow(center: CGPoint, radius: CGFloat, color: NSColor, alpha: CGFloat) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let colors = [color.withAlphaComponent(alpha).cgColor, color.withAlphaComponent(0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// MARK: - Icon

/// Draws the icon artwork designed on a 1024 grid into `rect`.
func drawIcon(in rect: CGRect) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.minX, yBy: rect.minY)
    transform.scale(by: rect.width / 1024)
    transform.concat()

    // Squircle background following the macOS icon grid.
    let tile = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    withShadow(blur: 28, offsetY: -12, alpha: 0.35) {
        NSGradient(starting: indigoLight, ending: violetDark)!.draw(in: tile, angle: -60)
    }
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    // Soft top-left light.
    drawGlow(center: CGPoint(x: 300, y: 900), radius: 700, color: .white, alpha: 0.22)
    NSGraphicsContext.restoreGraphicsState()

    // Three desktops; the middle one is active.
    let deskW: CGFloat = 196, deskH: CGFloat = 128, gap: CGFloat = 30
    let deskY: CGFloat = 640
    for index in 0..<3 {
        let x = 512 - deskW * 1.5 - gap + CGFloat(index) * (deskW + gap)
        let desk = NSBezierPath(roundedRect: CGRect(x: x, y: deskY, width: deskW, height: deskH), xRadius: 22, yRadius: 22)
        if index == 1 {
            withShadow(blur: 18, offsetY: -6, alpha: 0.25) {
                NSColor.white.setFill()
                desk.fill()
            }
            // Menu bar strip and a small window.
            indigo.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: CGRect(x: x + 18, y: deskY + deskH - 30, width: deskW - 36, height: 12), xRadius: 6, yRadius: 6).fill()
            indigo.withAlphaComponent(0.5).setFill()
            NSBezierPath(roundedRect: CGRect(x: x + 36, y: deskY + 22, width: deskW - 90, height: 58), xRadius: 10, yRadius: 10).fill()
        } else {
            NSColor.white.withAlphaComponent(0.32).setFill()
            desk.fill()
        }
    }

    // Mouse with a highlighted scroll wheel.
    let mouseRect = CGRect(x: 512 - 92, y: 190, width: 184, height: 280)
    let mouse = NSBezierPath(roundedRect: mouseRect, xRadius: 92, yRadius: 92)
    withShadow(blur: 22, offsetY: -8, alpha: 0.3) {
        NSColor.white.setFill()
        mouse.fill()
    }
    let seam = NSBezierPath()
    seam.move(to: CGPoint(x: 512, y: mouseRect.maxY))
    seam.line(to: CGPoint(x: 512, y: mouseRect.maxY - 108))
    seam.lineWidth = 6
    hex(0xD5D8F5).setStroke()
    seam.stroke()
    let wheel = NSBezierPath(roundedRect: CGRect(x: 512 - 17, y: mouseRect.maxY - 96, width: 34, height: 62), xRadius: 17, yRadius: 17)
    NSGradient(starting: indigoLight, ending: indigo)!.draw(in: wheel, angle: -90)

    // Left / right drag arrows.
    let arrowY = mouseRect.midY + 10
    drawArrow(from: CGPoint(x: 370, y: arrowY), to: CGPoint(x: 232, y: arrowY), width: 26, head: 50, color: .white)
    drawArrow(from: CGPoint(x: 654, y: arrowY), to: CGPoint(x: 792, y: arrowY), width: 26, head: 50, color: .white)

    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - README artwork

func drawBackdrop(_ rect: CGRect, radius: CGFloat) {
    let card = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGradient(starting: nightLight, ending: night)!.draw(in: card, angle: -35)
    NSGraphicsContext.saveGraphicsState()
    card.addClip()
    drawGlow(center: CGPoint(x: rect.minX + 280, y: rect.midY), radius: 760, color: indigo, alpha: 0.5)
    drawGlow(center: CGPoint(x: rect.maxX - 120, y: rect.maxY), radius: 520, color: violetDark, alpha: 0.45)
    NSGraphicsContext.restoreGraphicsState()
}

func drawPill(_ text: String, symbol: String, at origin: CGPoint) -> CGFloat {
    let font = NSFont.systemFont(ofSize: 24, weight: .medium)
    let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
    let width = textWidth + 92
    let pill = NSBezierPath(roundedRect: CGRect(x: origin.x, y: origin.y, width: width, height: 56), xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.1).setFill()
    pill.fill()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    pill.lineWidth = 1.5
    pill.stroke()
    drawSymbol(symbol, in: CGRect(x: origin.x + 22, y: origin.y + 14, width: 28, height: 28), color: indigoLight)
    _ = drawText(text, at: CGPoint(x: origin.x + 62, y: origin.y + 42), size: 24, weight: .medium, color: .white)
    return width
}

func drawSymbol(_ name: String, in rect: CGRect, color: NSColor) {
    let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .semibold)
        .applying(.init(paletteColors: [color]))
    guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    let size = image.size
    let scale = min(rect.width / size.width, rect.height / size.height)
    let drawRect = CGRect(x: rect.midX - size.width * scale / 2, y: rect.midY - size.height * scale / 2,
                          width: size.width * scale, height: size.height * scale)
    image.draw(in: drawRect)
}

func drawBanner(_ rect: CGRect) {
    drawBackdrop(rect, radius: 36)
    drawIcon(in: CGRect(x: 50, y: rect.midY - 230, width: 460, height: 460))
    let left: CGFloat = 530
    var y = rect.midY + 205
    y -= drawText("Scroll Wheel", at: CGPoint(x: left, y: y), size: 76, weight: .heavy, color: .white)
    y -= drawText("Mission Control", at: CGPoint(x: left, y: y), size: 76, weight: .heavy, color: indigoLight)
    y -= 24
    y -= drawText("Switch macOS desktops with any basic mouse.\nFree, open source, no trials.",
                  at: CGPoint(x: left, y: y), size: 30, weight: .regular, color: NSColor.white.withAlphaComponent(0.72), maxWidth: 900)
    y -= 44
    var x = left
    x += drawPill("Drag to switch", symbol: "arrow.left.and.right", at: CGPoint(x: x, y: y - 56)) + 16
    x += drawPill("Click for Mission Control", symbol: "square.grid.3x2", at: CGPoint(x: x, y: y - 56)) + 16
    _ = drawPill("Per-app off", symbol: "nosign", at: CGPoint(x: x, y: y - 56))
}

func drawGestureCard(_ rect: CGRect, symbol: String, title: String, body: String) {
    let card = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    NSColor.white.withAlphaComponent(0.06).setFill()
    card.fill()
    NSColor.white.withAlphaComponent(0.14).setStroke()
    card.lineWidth = 1.5
    card.stroke()

    let badge = CGRect(x: rect.minX + 36, y: rect.maxY - 36 - 88, width: 88, height: 88)
    NSGradient(starting: indigoLight, ending: violetDark)!
        .draw(in: NSBezierPath(roundedRect: badge, xRadius: 22, yRadius: 22), angle: -60)
    drawSymbol(symbol, in: badge.insetBy(dx: 22, dy: 22), color: .white)

    var y = badge.minY - 30
    y -= drawText(title, at: CGPoint(x: rect.minX + 36, y: y), size: 32, weight: .bold, color: .white, maxWidth: rect.width - 72)
    y -= 12
    _ = drawText(body, at: CGPoint(x: rect.minX + 36, y: y), size: 23, weight: .regular,
                 color: NSColor.white.withAlphaComponent(0.7), maxWidth: rect.width - 72)
}

func drawGestures(_ rect: CGRect) {
    drawBackdrop(rect, radius: 36)
    let cards: [(String, String, String)] = [
        ("arrow.left.and.right", "Hold wheel + drag",
         "Move exactly one desktop left or right. Release and drag again to keep going."),
        ("computermouse.fill", "Click the wheel",
         "Open Mission Control, show the app's windows, or keep a normal middle click."),
        ("nosign", "Exclude apps",
         "Blender and other 3D apps keep the middle button for orbiting and panning."),
    ]
    let pad: CGFloat = 48, gap: CGFloat = 28
    let width = (rect.width - pad * 2 - gap * 2) / 3
    for (index, card) in cards.enumerated() {
        let x = rect.minX + pad + CGFloat(index) * (width + gap)
        drawGestureCard(CGRect(x: x, y: rect.minY + pad, width: width, height: rect.height - pad * 2),
                        symbol: card.0, title: card.1, body: card.2)
    }
}

/// 1200x630 social preview card for the website.
func drawSocialCard(_ rect: CGRect) {
    drawBackdrop(rect, radius: 0)
    drawIcon(in: CGRect(x: rect.midX - 150, y: rect.maxY - 330, width: 300, height: 300))
    let title = NSAttributedString(string: "Scroll Wheel Mission Control", attributes: [
        .font: NSFont.systemFont(ofSize: 62, weight: .heavy), .foregroundColor: NSColor.white])
    title.draw(at: CGPoint(x: rect.midX - title.size().width / 2, y: 170))
    let tagline = NSAttributedString(string: "Switch macOS desktops with any basic mouse. Free forever.", attributes: [
        .font: NSFont.systemFont(ofSize: 30, weight: .regular), .foregroundColor: NSColor.white.withAlphaComponent(0.72)])
    tagline.draw(at: CGPoint(x: rect.midX - tagline.size().width / 2, y: 110))
}

// MARK: - Main

let fm = FileManager.default
try? fm.createDirectory(atPath: "docs/images", withIntermediateDirectories: true)
try? fm.createDirectory(atPath: "build/AppIcon.iconset", withIntermediateDirectories: true)

render(CGSize(width: 1024, height: 1024), to: "Resources/AppIcon-1024.png") { drawIcon(in: $0) }
render(CGSize(width: 512, height: 512), to: "docs/images/icon.png") { drawIcon(in: $0) }
render(CGSize(width: 1600, height: 640), to: "docs/images/banner.png") { drawBanner($0) }
render(CGSize(width: 1600, height: 400), to: "docs/images/gestures.png") { drawGestures($0) }
render(CGSize(width: 1200, height: 630), to: "docs/images/social-card.png") { drawSocialCard($0) }
