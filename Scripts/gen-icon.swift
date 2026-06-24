import CoreGraphics
import Foundation
import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: gen-icon.swift <output-path>")
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 256
let scale: CGFloat = 2.0
let pixelSize = Int(size * scale)

// Use CGContext (headless-safe) instead of NSImage.lockFocus()
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil,
    width: pixelSize,
    height: pixelSize,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create CGContext")
    exit(1)
}

ctx.scaleBy(x: scale, y: scale)

// Rounded rect background
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let radius = size * 0.2

ctx.beginPath()
ctx.move(to: CGPoint(x: radius, y: 0))
ctx.addLine(to: CGPoint(x: size - radius, y: 0))
ctx.addArc(center: CGPoint(x: size - radius, y: radius), radius: radius, startAngle: -CGFloat.pi / 2, endAngle: 0, clockwise: false)
ctx.addLine(to: CGPoint(x: size, y: size - radius))
ctx.addArc(center: CGPoint(x: size - radius, y: size - radius), radius: radius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)
ctx.addLine(to: CGPoint(x: radius, y: size))
ctx.addArc(center: CGPoint(x: radius, y: size - radius), radius: radius, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
ctx.addLine(to: CGPoint(x: 0, y: radius))
ctx.addArc(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: CGFloat.pi, endAngle: -CGFloat.pi / 2, clockwise: false)
ctx.closePath()

// Use system accent color (blue)
ctx.setFillColor(CGColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0))
ctx.fillPath()

// Clipboard icon — draw a simplified clipboard shape
let iconRect = CGRect(x: size * 0.2, y: size * 0.18, width: size * 0.6, height: size * 0.64)
let iconRadius = size * 0.06
let clipW = iconRect.width
let clipH = iconRect.height
let cx = iconRect.origin.x
let cy = iconRect.origin.y

ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1.0))

// Clipboard body — rounded rect
ctx.beginPath()
ctx.move(to: CGPoint(x: cx + iconRadius, y: cy))
ctx.addLine(to: CGPoint(x: cx + clipW - iconRadius, y: cy))
ctx.addArc(center: CGPoint(x: cx + clipW - iconRadius, y: cy + iconRadius), radius: iconRadius, startAngle: -CGFloat.pi / 2, endAngle: 0, clockwise: false)
ctx.addLine(to: CGPoint(x: cx + clipW, y: cy + clipH - iconRadius))
ctx.addArc(center: CGPoint(x: cx + clipW - iconRadius, y: cy + clipH - iconRadius), radius: iconRadius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)
ctx.addLine(to: CGPoint(x: cx + iconRadius, y: cy + clipH))
ctx.addArc(center: CGPoint(x: cx + iconRadius, y: cy + clipH - iconRadius), radius: iconRadius, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
ctx.addLine(to: CGPoint(x: cx, y: cy + iconRadius))
ctx.addArc(center: CGPoint(x: cx + iconRadius, y: cy + iconRadius), radius: iconRadius, startAngle: CGFloat.pi, endAngle: -CGFloat.pi / 2, clockwise: false)
ctx.closePath()
ctx.fillPath()

// Clipboard top clip
let clipTopW = clipW * 0.45
let clipTopH = size * 0.08
let clipTopX = cx + (clipW - clipTopW) / 2
let clipTopY = cy - clipTopH * 0.7

ctx.beginPath()
ctx.move(to: CGPoint(x: clipTopX + iconRadius, y: clipTopY))
ctx.addLine(to: CGPoint(x: clipTopX + clipTopW - iconRadius, y: clipTopY))
ctx.addArc(center: CGPoint(x: clipTopX + clipTopW - iconRadius, y: clipTopY + iconRadius), radius: iconRadius, startAngle: -CGFloat.pi / 2, endAngle: 0, clockwise: false)
ctx.addLine(to: CGPoint(x: clipTopX + clipTopW, y: clipTopY + clipTopH - iconRadius))
ctx.addArc(center: CGPoint(x: clipTopX + clipTopW - iconRadius, y: clipTopY + clipTopH - iconRadius), radius: iconRadius, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)
ctx.addLine(to: CGPoint(x: clipTopX + iconRadius, y: clipTopY + clipTopH))
ctx.addArc(center: CGPoint(x: clipTopX + iconRadius, y: clipTopY + clipTopH - iconRadius), radius: iconRadius, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
ctx.addLine(to: CGPoint(x: clipTopX, y: clipTopY + iconRadius))
ctx.addArc(center: CGPoint(x: clipTopX + iconRadius, y: clipTopY + iconRadius), radius: iconRadius, startAngle: CGFloat.pi, endAngle: -CGFloat.pi / 2, clockwise: false)
ctx.closePath()
ctx.fillPath()

// Lines on clipboard
let lineCount = 4
let lineInsetX = clipW * 0.2
let lineStartY = cy + clipH * 0.28
let lineSpacing = clipH * 0.15
ctx.setFillColor(CGColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0))
for i in 0..<lineCount {
    let ly = lineStartY + CGFloat(i) * lineSpacing
    let lw = i == lineCount - 1 ? clipW * 0.35 : clipW - lineInsetX * 2
    let lr = size * 0.015
    ctx.beginPath()
    ctx.move(to: CGPoint(x: cx + lineInsetX + lr, y: ly))
    ctx.addLine(to: CGPoint(x: cx + lineInsetX + lw - lr, y: ly))
    ctx.addArc(center: CGPoint(x: cx + lineInsetX + lw - lr, y: ly + lr), radius: lr, startAngle: -CGFloat.pi / 2, endAngle: 0, clockwise: false)
    ctx.addLine(to: CGPoint(x: cx + lineInsetX + lw, y: ly + lr * 2))
    ctx.addArc(center: CGPoint(x: cx + lineInsetX + lw - lr, y: ly + lr), radius: lr, startAngle: 0, endAngle: CGFloat.pi / 2, clockwise: false)
    ctx.addLine(to: CGPoint(x: cx + lineInsetX + lr, y: ly + lr * 2))
    ctx.addArc(center: CGPoint(x: cx + lineInsetX + lr, y: ly + lr), radius: lr, startAngle: CGFloat.pi / 2, endAngle: CGFloat.pi, clockwise: false)
    ctx.closePath()
    ctx.fillPath()
}

guard let cgImage = ctx.makeImage() else {
    print("Failed to create CGImage")
    exit(1)
}

let rep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to create PNG data")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
try pngData.write(to: url)
print("Icon written to \(outputPath)")