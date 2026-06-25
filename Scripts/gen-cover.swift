import AppKit

let width = 192
let height = 128
let rect = NSRect(x: 0, y: 0, width: width, height: height)

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .calibratedRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

// 设置 72 DPI（标准屏幕分辨率）
rep.size = NSSize(width: width, height: height)

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context

// ── 背景渐变 ──────────────────────────────────────────
let gradient = NSGradient(
    colors: [
        NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0),
        NSColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1.0),
    ]
)!
gradient.draw(in: rect, angle: 135)

// ── 顶部装饰线 ────────────────────────────────────────
let accent = NSColor(red: 0.35, green: 0.70, blue: 0.95, alpha: 1.0)
accent.setFill()
NSRect(x: 0, y: height - 4, width: width, height: 4).fill()

// ── 标题 ──────────────────────────────────────────────
let title = "LocalPaste"
let titleFont = NSFont.systemFont(ofSize: 26, weight: .bold)
let titleAttr: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor.white,
]
let tSize = title.size(withAttributes: titleAttr)
let tX = (CGFloat(width) - tSize.width) / 2
let tY = (CGFloat(height) - tSize.height) / 2 + 10
title.draw(at: NSPoint(x: tX, y: tY), withAttributes: titleAttr)

// ── 副标题 ────────────────────────────────────────────
let sub = "剪贴板历史 · 离线 · 开源"
let subFont = NSFont.systemFont(ofSize: 12, weight: .medium)
let subAttr: [NSAttributedString.Key: Any] = [
    .font: subFont,
    .foregroundColor: NSColor.white.withAlphaComponent(0.7),
]
let sSize = sub.size(withAttributes: subAttr)
let sX = (CGFloat(width) - sSize.width) / 2
sub.draw(at: NSPoint(x: sX, y: tY - sSize.height - 6), withAttributes: subAttr)

NSGraphicsContext.restoreGraphicsState()

// ── 导出 PNG ──────────────────────────────────────────
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    print("ERROR: encode failed")
    exit(1)
}

let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("cover.png")
try pngData.write(to: url)
print("✅ cover.png — \(pngData.count) bytes, \(width)×\(height) px")
