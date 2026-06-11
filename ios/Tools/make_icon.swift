// Arz Radar app icon — indigo brand, "radar ping on a rising chart":
// indigo gradient field + a clean smooth rising line that ends in a glowing
// dot wrapped in concentric radar rings. Run: swift Tools/make_icon.swift
import AppKit

let S: CGFloat = 1024
let image = NSImage(size: CGSize(width: S, height: S))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// ---- Background: deep indigo diagonal gradient ----
let bg = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.40, green: 0.45, blue: 0.95, alpha: 1).cgColor, // bright indigo
        NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.70, alpha: 1).cgColor, // deep indigo
    ] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// ---- Ping point (top-right of the rising line) ----
let ping = CGPoint(x: 752, y: 712)

// ---- Subtle radar grid: faint concentric arcs behind the ping ----
NSColor.white.withAlphaComponent(0.09).setStroke()
for r: CGFloat in [250, 370] {
    let p = NSBezierPath()
    p.appendArc(withCenter: ping, radius: r, startAngle: 145, endAngle: 305)
    p.lineWidth = 7
    p.stroke()
}

// ---- Rising chart line (white, smooth, confident rise) ----
let pts = [CGPoint(x: 210, y: 350), CGPoint(x: 405, y: 455),
           CGPoint(x: 575, y: 500), ping]
let line = NSBezierPath()
line.move(to: pts[0])
for i in 0..<pts.count - 1 {
    let a = pts[i], b = pts[i + 1]
    let cx = (a.x + b.x) / 2
    line.curve(to: b, controlPoint1: CGPoint(x: cx, y: a.y), controlPoint2: CGPoint(x: cx, y: b.y))
}
line.lineWidth = 58
line.lineCapStyle = .round
line.lineJoinStyle = .round
NSColor.white.setStroke()
line.stroke()

// ---- Radar ping: concentric rings + halo + solid dot ----
for (r, lw, a): (CGFloat, CGFloat, CGFloat) in [(102, 11, 0.34), (162, 9, 0.18)] {
    NSColor.white.withAlphaComponent(a).setStroke()
    let ring = NSBezierPath(ovalIn: CGRect(x: ping.x - r, y: ping.y - r, width: r * 2, height: r * 2))
    ring.lineWidth = lw
    ring.stroke()
}
NSColor.white.withAlphaComponent(0.25).setFill()
NSBezierPath(ovalIn: CGRect(x: ping.x - 70, y: ping.y - 70, width: 140, height: 140)).fill()
NSColor.white.setFill()
NSBezierPath(ovalIn: CGRect(x: ping.x - 46, y: ping.y - 46, width: 92, height: 92)).fill()

image.unlockFocus()
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Wrote AppIcon.png")
