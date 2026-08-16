#!/usr/bin/env swift
import AppKit
import Foundation

let root = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let docs = (root as NSString).appendingPathComponent("docs")
let iconPath = (docs as NSString).appendingPathComponent("app-icon.png")
let outPath = (docs as NSString).appendingPathComponent("banner.png")

guard let icon = NSImage(contentsOfFile: iconPath) else {
    fputs("Missing \(iconPath) — run generate-icons.sh first\n", stderr)
    exit(1)
}

let width = 1280
let height = 320
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bounds = NSRect(x: 0, y: 0, width: width, height: height)

// Background gradient
let gradient = NSGradient(colors: [
    NSColor(red: 0.10, green: 0.07, blue: 0.19, alpha: 1),
    NSColor(red: 0.23, green: 0.12, blue: 0.36, alpha: 1),
    NSColor(red: 0.79, green: 0.39, blue: 0.26, alpha: 1),
])!
gradient.draw(in: bounds, angle: 35)

// Subtle orange glow behind icon
let glow = NSGradient(colors: [
    NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0.22),
    NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 0),
])!
glow.draw(in: NSRect(x: 40, y: 40, width: 280, height: 280), angle: 0)

// App icon
let iconSide: CGFloat = 184
let iconY = (CGFloat(height) - iconSide) / 2
icon.draw(in: NSRect(x: 72, y: iconY, width: iconSide, height: iconSide))

// Title
let title = "Claudamangala" as NSString
let titleFont = NSFont.systemFont(ofSize: 62, weight: .bold)
title.draw(
    at: NSPoint(x: 300, y: 168),
    withAttributes: [
        .font: titleFont,
        .foregroundColor: NSColor.white,
    ]
)

// Subtitle — keep short so it never clips on GitHub
let subtitle = "Claude Code account switcher for macOS" as NSString
subtitle.draw(
    at: NSPoint(x: 302, y: 118),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .regular),
        .foregroundColor: NSColor(white: 0.95, alpha: 0.88),
    ]
)

// Feature chips
let chips = "refresh  ·  copy  ·  apply  ·  rename  ·  add" as NSString
chips.draw(
    at: NSPoint(x: 302, y: 82),
    withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(white: 1, alpha: 0.55),
    ]
)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    fputs("PNG encode failed\n", stderr)
    exit(1)
}
try data.write(to: URL(fileURLWithPath: outPath))
print("✓ Wrote \(outPath)")
