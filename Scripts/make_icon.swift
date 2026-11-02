// SPDX-License-Identifier: GPL-3.0-or-later
// Curatare uygulama simgesini (AppIcon.icns) çizer: zümrüt/turkuaz cam gövde üzerinde temizlik halkası ve parıltı yıldızları.
// Kullanım: swift Scripts/make_icon.swift Resources/AppIcon.icns [--preview önizleme.png]
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
let outputPath = arguments.first ?? "Resources/AppIcon.icns"
let previewPath = arguments.firstIndex(of: "--preview").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

func drawSparkle(in ctx: CGContext, center: CGPoint, radius: CGFloat, color: CGColor) {
    ctx.saveGState()
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func drawIcon(in ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = roundedRect(body, 186)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: rgb(0x000000, 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(rgb(0x065F46))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgb(0x10B981), rgb(0x0D9488), rgb(0x0369A1)], [0, 0.52, 1]),
        start: CGPoint(x: 160, y: 924), end: CGPoint(x: 864, y: 100), options: []
    )
    ctx.drawLinearGradient(
        gradient([rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0)], [0, 1]),
        start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 560), options: []
    )
    ctx.restoreGState()

    // İç temizlik kalkanı / disk halkası
    ctx.saveGState()
    ctx.setLineWidth(54)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.92))
    ctx.addArc(center: CGPoint(x: 512, y: 512), radius: 220, startAngle: .pi * 0.2, endAngle: .pi * 1.75, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    // Parıltı yıldızları (Curatare temizlik simgesi)
    drawSparkle(in: ctx, center: CGPoint(x: 512, y: 512), radius: 135, color: rgb(0xFFFFFF, 0.98))
    drawSparkle(in: ctx, center: CGPoint(x: 690, y: 690), radius: 68, color: rgb(0xA7F3D0, 0.95))
    drawSparkle(in: ctx, center: CGPoint(x: 345, y: 655), radius: 44, color: rgb(0xE0F2FE, 0.9))
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let ctx = context.cgContext
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: ctx)
    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let fileManager = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("Curatare-\(UUID().uuidString).iconset", isDirectory: true)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconset) }

let variants: [(Int, String)] = [
    (16, "16x16"), (32, "16x16@2x"), (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"), (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]
for (size, name) in variants {
    try png(size: size).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}

let outURL = URL(fileURLWithPath: outputPath)
try fileManager.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputPath]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil başarısız oldu\n".data(using: .utf8)!)
    exit(1)
}
if let previewPath {
    try png(size: 512).write(to: URL(fileURLWithPath: previewPath))
}
print("Simge oluşturuldu: \(outputPath)")
