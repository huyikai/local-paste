import Cocoa

guard CommandLine.arguments.count > 1 else {
    print("Usage: gen-icon.swift <output-path>")
    exit(1)
}

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 256

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.2, yRadius: size * 0.2)
NSColor.controlAccentColor.setFill()
path.fill()

if let icon = NSImage(systemSymbolName: "clipboard.fill", accessibilityDescription: nil) {
    icon.size = NSSize(width: size * 0.5, height: size * 0.5)
    icon.draw(in: NSRect(x: size * 0.25, y: size * 0.25, width: size * 0.5, height: size * 0.5))
}

img.unlockFocus()

guard let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
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
