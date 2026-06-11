// App icon: green gradient field with a rising line-chart + an "alarm"/radar dot,
// matching the green brand. Run: swift Tools/make_icon.swift
import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Indigo gradient background (brand accent #4B57E0).
let colors = [
    NSColor(calibratedRed: 0.29, green: 0.34, blue: 0.88, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.95, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])

// Rising line chart (white).
let line = NSBezierPath()
let pts = [CGPoint(x: 200, y: 380), CGPoint(x: 360, y: 520), CGPoint(x: 500, y: 440),
           CGPoint(x: 640, y: 640), CGPoint(x: 824, y: 760)]
line.move(to: pts[0])
for p in pts.dropFirst() { line.line(to: p) }
line.lineWidth = 54
line.lineCapStyle = .round
line.lineJoinStyle = .round
NSColor.white.setStroke()
line.stroke()

// Dot at the peak.
NSColor.white.setFill()
NSBezierPath(ovalIn: CGRect(x: pts.last!.x - 46, y: pts.last!.y - 46, width: 92, height: 92)).fill()
NSColor(calibratedRed: 0.29, green: 0.34, blue: 0.88, alpha: 1).setFill()
NSBezierPath(ovalIn: CGRect(x: pts.last!.x - 22, y: pts.last!.y - 22, width: 44, height: 44)).fill()

image.unlockFocus()
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Wrote AppIcon.png")
