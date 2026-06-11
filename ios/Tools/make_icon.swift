// Placeholder icon: red gradient field with a rising bar-chart + a calendar-dot
// "radar" sweep, evoking dividend/IPO calendar. Run: swift Tools/make_icon.swift
import AppKit

let size = CGSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let colors = [
    NSColor(calibratedRed: 0.78, green: 0.12, blue: 0.28, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.95, green: 0.29, blue: 0.45, alpha: 1).cgColor,
]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])

// Ascending bars (growth).
let barColor = NSColor.white
let heights: [CGFloat] = [240, 360, 500, 660]
let barW: CGFloat = 110
let gap: CGFloat = 40
let totalW = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
var x = (size.width - totalW) / 2
for h in heights {
    barColor.withAlphaComponent(0.92).setFill()
    let rect = CGRect(x: x, y: 240, width: barW, height: h)
    NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24).fill()
    x += barW + gap
}

// Coin dot on top of the tallest bar.
NSColor(calibratedRed: 1, green: 0.86, blue: 0.4, alpha: 1).setFill()
NSBezierPath(ovalIn: CGRect(x: x - barW - 16, y: 880, width: 150, height: 150)).fill()

image.unlockFocus()
let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
print("Wrote AppIcon.png")
