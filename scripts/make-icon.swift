#!/usr/bin/env swift
//
// Renders Support/AppIcon.png (1024×1024) with CoreGraphics. No design tool
// or network access is required, which keeps the repository source-only.

import AppKit
import CoreGraphics
import Foundation

let size = 1024
let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Support/AppIcon.png")

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create icon context")
}

context.setAllowsAntialiasing(true)
context.interpolationQuality = .high

let rect = CGRect(x: 0, y: 0, width: size, height: size)
let radius: CGFloat = 220
let path = CGPath(roundedRect: rect.insetBy(dx: 32, dy: 32), cornerWidth: radius, cornerHeight: radius, transform: nil)
context.addPath(path)
context.clip()

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(srgbRed: 0.10, green: 0.38, blue: 0.95, alpha: 1).cgColor,
        NSColor(srgbRed: 0.12, green: 0.72, blue: 0.78, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 120, y: 900),
    end: CGPoint(x: 900, y: 120),
    options: []
)

// Soft highlight.
context.setFillColor(NSColor.white.withAlphaComponent(0.10).cgColor)
context.fillEllipse(in: CGRect(x: -120, y: 560, width: 900, height: 700))

// Viewfinder corners.
context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(52)
context.setLineCap(.round)
let inset: CGFloat = 230
let arm: CGFloat = 170
let corners: [(CGPoint, CGPoint, CGPoint)] = [
    (CGPoint(x: inset + arm, y: inset), CGPoint(x: inset, y: inset), CGPoint(x: inset, y: inset + arm)),
    (CGPoint(x: 1024 - inset - arm, y: inset), CGPoint(x: 1024 - inset, y: inset), CGPoint(x: 1024 - inset, y: inset + arm)),
    (CGPoint(x: inset + arm, y: 1024 - inset), CGPoint(x: inset, y: 1024 - inset), CGPoint(x: inset, y: 1024 - inset - arm)),
    (CGPoint(x: 1024 - inset - arm, y: 1024 - inset), CGPoint(x: 1024 - inset, y: 1024 - inset), CGPoint(x: 1024 - inset, y: 1024 - inset - arm))
]
for (a, b, c) in corners {
    context.move(to: a)
    context.addLine(to: b)
    context.addLine(to: c)
    context.strokePath()
}

// Selection rectangle.
let selection = CGRect(x: 330, y: 390, width: 364, height: 250)
context.setFillColor(NSColor.white.withAlphaComponent(0.16).cgColor)
context.fill(selection)
context.setStrokeColor(NSColor.white.cgColor)
context.setLineWidth(34)
context.stroke(selection.insetBy(dx: 17, dy: 17))

// A small pin dot in the middle, echoing the pin-to-desktop feature.
context.setFillColor(NSColor.white.cgColor)
context.fillEllipse(in: CGRect(x: 480, y: 500, width: 64, height: 64))

context.setStrokeColor(NSColor.black.withAlphaComponent(0.12).cgColor)
context.setLineWidth(8)
context.addPath(path)
context.strokePath()

guard let image = context.makeImage() else { fatalError("Could not render icon") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try data.write(to: output)
print("Wrote \(output.path)")
