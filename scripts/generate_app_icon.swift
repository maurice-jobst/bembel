#!/usr/bin/env swift
// Draws the app icon: a grey stoneware Bembel with cobalt decoration on the
// app's accent cobalt. Deterministic — same input, same bytes — so the PNG in
// AppIcon.appiconset is generated, never hand-edited (same rule as rings.json).
//
//     swift scripts/generate_app_icon.swift
//
// App Store icons must be 1024×1024 with no alpha channel; iOS masks the
// corners itself, so the canvas is filled edge to edge.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let cobalt = CGColor(red: 0.114, green: 0.306, blue: 0.620, alpha: 1)  // AccentColor
let cobaltDeep = CGColor(red: 0.078, green: 0.220, blue: 0.470, alpha: 1)
let stoneware = CGColor(red: 0.925, green: 0.918, blue: 0.894, alpha: 1)
let stonewareShade = CGColor(red: 0.827, green: 0.816, blue: 0.784, alpha: 1)

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Flip to a top-left origin so the coordinates below read like a drawing.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

// Ground: vertical cobalt gradient, slightly deeper at the bottom.
let gradient = CGGradient(
    colorsSpace: space, colors: [cobalt, cobaltDeep] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])

/// The jug silhouette: rim, neck flaring into a bulbous body, flat base.
/// One closed path, symmetric about x = 512 except for the handle.
func jugPath() -> CGMutablePath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 420, y: 210))
    // Rim: a slight outward lip.
    p.addLine(to: CGPoint(x: 604, y: 210))
    p.addQuadCurve(to: CGPoint(x: 612, y: 252), control: CGPoint(x: 616, y: 228))
    // Neck tapering in, then the shoulder flaring out.
    p.addQuadCurve(to: CGPoint(x: 596, y: 380), control: CGPoint(x: 596, y: 310))
    p.addCurve(
        to: CGPoint(x: 762, y: 640), control1: CGPoint(x: 700, y: 430),
        control2: CGPoint(x: 762, y: 520))
    // Belly down to the base.
    p.addCurve(
        to: CGPoint(x: 640, y: 900), control1: CGPoint(x: 762, y: 780),
        control2: CGPoint(x: 712, y: 870))
    p.addLine(to: CGPoint(x: 384, y: 900))
    p.addCurve(
        to: CGPoint(x: 262, y: 640), control1: CGPoint(x: 312, y: 870),
        control2: CGPoint(x: 262, y: 780))
    p.addCurve(
        to: CGPoint(x: 428, y: 380), control1: CGPoint(x: 262, y: 520),
        control2: CGPoint(x: 324, y: 430))
    p.addQuadCurve(to: CGPoint(x: 412, y: 252), control: CGPoint(x: 428, y: 310))
    p.addQuadCurve(to: CGPoint(x: 420, y: 210), control: CGPoint(x: 408, y: 228))
    p.closeSubpath()
    return p
}

// Handle: a stroked arc on the right, behind nothing — drawn first so the
// body sits on top of its inner end.
let handle = CGMutablePath()
handle.move(to: CGPoint(x: 700, y: 420))
handle.addCurve(
    to: CGPoint(x: 720, y: 730), control1: CGPoint(x: 880, y: 460),
    control2: CGPoint(x: 872, y: 680))
ctx.setStrokeColor(stonewareShade)
ctx.setLineWidth(58)
ctx.setLineCap(.round)
ctx.addPath(handle)
ctx.strokePath()

// Body.
ctx.setFillColor(stoneware)
ctx.addPath(jugPath())
ctx.fillPath()

// Decoration is clipped to the silhouette so bands never bleed onto the ground.
ctx.saveGState()
ctx.addPath(jugPath())
ctx.clip()

// Two thin cobalt bands where neck meets shoulder.
ctx.setFillColor(cobalt)
ctx.fill(CGRect(x: 262, y: 396, width: 500, height: 18))
ctx.fill(CGRect(x: 262, y: 436, width: 500, height: 10))
// One band above the base.
ctx.fill(CGRect(x: 262, y: 830, width: 500, height: 14))

// The classic diamond on the belly, outlined.
let diamond = CGMutablePath()
diamond.move(to: CGPoint(x: 512, y: 520))
diamond.addLine(to: CGPoint(x: 632, y: 650))
diamond.addLine(to: CGPoint(x: 512, y: 780))
diamond.addLine(to: CGPoint(x: 392, y: 650))
diamond.closeSubpath()
ctx.setStrokeColor(cobalt)
ctx.setLineWidth(26)
ctx.setLineJoin(.miter)
ctx.addPath(diamond)
ctx.strokePath()
// A solid dot at its centre.
ctx.setFillColor(cobalt)
ctx.fillEllipse(in: CGRect(x: 482, y: 620, width: 60, height: 60))

ctx.restoreGState()

let image = ctx.makeImage()!
let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
let out = repoRoot.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(out.path)") }
print("wrote \(out.path)")
