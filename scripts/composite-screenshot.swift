#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: composite-screenshot.swift <capture.png> <output.png>\n", stderr)
    exit(1)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard
    let capture = NSImage(contentsOf: inputURL),
    let captureRep = NSBitmapImageRep(data: capture.tiffRepresentation ?? Data())
else {
    fputs("failed to read capture image\n", stderr)
    exit(1)
}

let width = captureRep.pixelsWide
let height = captureRep.pixelsHigh

guard
    let output = NSBitmapImageRep(
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
    )
else {
    fputs("failed to allocate output bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: output)

NSColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
capture.draw(in: NSRect(x: 0, y: 0, width: width, height: height))

NSGraphicsContext.restoreGraphicsState()

guard let png = output.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: outputURL)
} catch {
    fputs("failed to write output: \(error)\n", stderr)
    exit(1)
}
