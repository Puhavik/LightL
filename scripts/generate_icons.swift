import Foundation
import AppKit
import CoreGraphics

// Helper for squircle path
func createSquirclePath(rect: CGRect, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let x = rect.origin.x
    let y = rect.origin.y
    let w = rect.size.width
    let h = rect.size.height
    let r = min(radius, min(w, h) / 2.0)
    path.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r)
    return path
}

// Helper for 4-pointed AI sparkle (curved diamond)
func createSparklePath(center: CGPoint, size: CGFloat, pinch: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let r = size / 2.0
    let p = r * pinch
    
    // In flipped coords (y down):
    // Top point
    path.move(to: CGPoint(x: center.x, y: center.y - r))
    // Curve to Right point
    path.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: CGPoint(x: center.x + p, y: center.y - p))
    // Curve to Bottom point
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: CGPoint(x: center.x + p, y: center.y + p))
    // Curve to Left point
    path.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: CGPoint(x: center.x - p, y: center.y + p))
    // Curve back to Top point
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: CGPoint(x: center.x - p, y: center.y - p))
    path.closeSubpath()
    return path
}

// Helper for rounded L-monogram
func createLPath(stemX: CGFloat, stemY: CGFloat, stemW: CGFloat, stemH: CGFloat, armW: CGFloat, cornerRadius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let r = cornerRadius
    
    // Flipped coordinates (y increases downwards)
    // Top-left of stem
    path.move(to: CGPoint(x: stemX + r, y: stemY))
    // Top-right of stem
    path.addLine(to: CGPoint(x: stemX + stemW - r, y: stemY))
    path.addArc(tangent1End: CGPoint(x: stemX + stemW, y: stemY), tangent2End: CGPoint(x: stemX + stemW, y: stemY + r), radius: r)
    
    // Inner elbow (top of horizontal arm)
    let innerCornerY = stemY + stemH - stemW
    path.addLine(to: CGPoint(x: stemX + stemW, y: innerCornerY - r))
    path.addArc(tangent1End: CGPoint(x: stemX + stemW, y: innerCornerY), tangent2End: CGPoint(x: stemX + stemW + r, y: innerCornerY), radius: r)
    
    // Far-right tip of horizontal arm
    let armEndX = stemX + stemW + armW
    path.addLine(to: CGPoint(x: armEndX - r, y: innerCornerY))
    path.addArc(tangent1End: CGPoint(x: armEndX, y: innerCornerY), tangent2End: CGPoint(x: armEndX, y: innerCornerY + r), radius: r)
    
    // Bottom-right of arm
    let bottomY = stemY + stemH
    path.addLine(to: CGPoint(x: armEndX, y: bottomY - r))
    path.addArc(tangent1End: CGPoint(x: armEndX, y: bottomY), tangent2End: CGPoint(x: armEndX - r, y: bottomY), radius: r)
    
    // Bottom-left corner of L
    path.addLine(to: CGPoint(x: stemX + r, y: bottomY))
    path.addArc(tangent1End: CGPoint(x: stemX, y: bottomY), tangent2End: CGPoint(x: stemX, y: bottomY - r), radius: r)
    
    // Up along left side to top-left
    path.addLine(to: CGPoint(x: stemX, y: stemY + r))
    path.addArc(tangent1End: CGPoint(x: stemX, y: stemY), tangent2End: CGPoint(x: stemX + r, y: stemY), radius: r)
    path.closeSubpath()
    
    return path
}

func renderAppIcon1024() -> CGImage {
    let size = 1024
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!
    
    // Invert Y so (0,0) is top-left
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1.0, y: -1.0)
    
    // Apple macOS HIG: 824x824 squircle centered horizontally, placed at y=95 to leave bottom room for drop shadow
    let squircleRect = CGRect(x: 100, y: 95, width: 824, height: 824)
    let squirclePath = createSquirclePath(rect: squircleRect, radius: 185)
    
    // 1. Apple Drop Shadows (under inverted CTM, negative height casts shadow DOWNWARDS)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -28),
        blur: 40,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.36)
    )
    context.addPath(squirclePath)
    context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1.0))
    context.fillPath()
    context.restoreGState()
    
    // Ambient softer shadow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -10),
        blur: 18,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.22)
    )
    context.addPath(squirclePath)
    context.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1.0))
    context.fillPath()
    context.restoreGState()
    
    // 2. Base Squircle Surface
    context.saveGState()
    context.addPath(squirclePath)
    context.clip()
    
    // Background gradient: Deep Slate / Midnight Sapphire to Obsidian
    let bgColors = [
        CGColor(red: 0.09, green: 0.12, blue: 0.23, alpha: 1.0), // Top: #171F3B
        CGColor(red: 0.05, green: 0.07, blue: 0.14, alpha: 1.0), // Mid: #0D1224
        CGColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1.0)  // Bottom: #050A14
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations)!
    context.drawLinearGradient(
        bgGradient,
        start: CGPoint(x: 512, y: 95),
        end: CGPoint(x: 512, y: 919),
        options: []
    )
    
    // Ambient electric cyan glow behind sparkle
    let flareColors = [
        CGColor(red: 0.10, green: 0.65, blue: 1.0, alpha: 0.24),
        CGColor(red: 0.05, green: 0.35, blue: 0.95, alpha: 0.10),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    let flareGradient = CGGradient(colorsSpace: colorSpace, colors: flareColors, locations: [0.0, 0.55, 1.0])!
    context.drawRadialGradient(
        flareGradient,
        startCenter: CGPoint(x: 640, y: 380),
        startRadius: 20,
        endCenter: CGPoint(x: 640, y: 380),
        endRadius: 380,
        options: []
    )
    
    // Soft ambient top-left specular highlight
    let topGlowColors = [
        CGColor(red: 0.40, green: 0.55, blue: 1.0, alpha: 0.14),
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    ] as CFArray
    let topGlow = CGGradient(colorsSpace: colorSpace, colors: topGlowColors, locations: [0.0, 1.0])!
    context.drawRadialGradient(
        topGlow,
        startCenter: CGPoint(x: 280, y: 200),
        startRadius: 10,
        endCenter: CGPoint(x: 280, y: 200),
        endRadius: 360,
        options: []
    )
    
    // 3. "L" Monogram
    let stemX: CGFloat = 330
    let stemY: CGFloat = 275
    let stemW: CGFloat = 110
    let stemH: CGFloat = 460
    let armW: CGFloat = 260
    let lCornerRadius: CGFloat = 24
    let lPath = createLPath(stemX: stemX, stemY: stemY, stemW: stemW, stemH: stemH, armW: armW, cornerRadius: lCornerRadius)
    
    // Shadow under "L" (dy = -18 casts down)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -18),
        blur: 28,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.48)
    )
    context.addPath(lPath)
    context.setFillColor(CGColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1.0))
    context.fillPath()
    context.restoreGState()
    
    // "L" Frost White to Cool Azure Gradient Fill
    context.saveGState()
    context.addPath(lPath)
    context.clip()
    let lColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // Pure white top-left
        CGColor(red: 0.93, green: 0.97, blue: 1.0, alpha: 1.0),   // Frost Ice #EDF7FF
        CGColor(red: 0.80, green: 0.90, blue: 0.99, alpha: 1.0)   // Light Azure #CCE6FD
    ] as CFArray
    let lGradient = CGGradient(colorsSpace: colorSpace, colors: lColors, locations: [0.0, 0.55, 1.0])!
    context.drawLinearGradient(
        lGradient,
        start: CGPoint(x: stemX, y: stemY),
        end: CGPoint(x: stemX + stemW + armW, y: stemY + stemH),
        options: []
    )
    
    // Subtle inner bevel on "L"
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.45))
    context.setLineWidth(2.0)
    context.addPath(lPath)
    context.strokePath()
    context.restoreGState()
    
    // 4. AI Sparkle (✦)
    let sparkCenter = CGPoint(x: 640, y: 385)
    let sparkSize: CGFloat = 210
    let sparkPath = createSparklePath(center: sparkCenter, size: sparkSize, pinch: 0.16)
    
    // Sparkle Outer Glow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -8),
        blur: 32,
        color: CGColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 0.55)
    )
    context.addPath(sparkPath)
    context.setFillColor(CGColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1.0))
    context.fillPath()
    context.restoreGState()
    
    // Sparkle Gradient Fill (Brilliant Center to Electric Cyan & Azure)
    context.saveGState()
    context.addPath(sparkPath)
    context.clip()
    let sparkColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),      // Center white hot
        CGColor(red: 0.45, green: 0.88, blue: 1.0, alpha: 1.0),   // Electric Cyan #73E0FF
        CGColor(red: 0.05, green: 0.58, blue: 1.0, alpha: 1.0)    // Azure #0D94FF
    ] as CFArray
    let sparkGradient = CGGradient(colorsSpace: colorSpace, colors: sparkColors, locations: [0.0, 0.45, 1.0])!
    context.drawRadialGradient(
        sparkGradient,
        startCenter: sparkCenter,
        startRadius: 0,
        endCenter: sparkCenter,
        endRadius: sparkSize / 2.0,
        options: []
    )
    context.restoreGState()
    
    // Delicate micro-spark for extra Apple-style magic
    let miniCenter = CGPoint(x: 735, y: 490)
    let miniSize: CGFloat = 55
    let miniPath = createSparklePath(center: miniCenter, size: miniSize, pinch: 0.18)
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -4),
        blur: 14,
        color: CGColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 0.4)
    )
    context.addPath(miniPath)
    context.setFillColor(CGColor(red: 0.88, green: 0.96, blue: 1.0, alpha: 0.95))
    context.fillPath()
    context.restoreGState()
    
    // 5. Apple HIG Glass Rim Highlight
    context.saveGState()
    context.setLineWidth(2.0)
    context.addPath(squirclePath)
    context.replacePathWithStrokedPath()
    context.clip()
    
    let rimColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.32), // Bright top rim reflection
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08), // Mid
        CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.25)  // Dark bottom bevel
    ] as CFArray
    let rimGradient = CGGradient(colorsSpace: colorSpace, colors: rimColors, locations: [0.0, 0.4, 1.0])!
    context.drawLinearGradient(
        rimGradient,
        start: CGPoint(x: 512, y: 95),
        end: CGPoint(x: 512, y: 919),
        options: []
    )
    context.restoreGState()
    
    context.restoreGState() // Squircle clip
    
    return context.makeImage()!
}

func renderMenuBarIcon(points: CGFloat, scale: CGFloat) -> CGImage {
    let pixelSize = Int(points * scale)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: pixelSize * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!
    
    // Invert Y so (0,0) is top-left
    context.translateBy(x: 0, y: CGFloat(pixelSize))
    context.scaleBy(x: scale, y: -scale)
    
    // Apple Template Image: Pure black drawing, system automatically handles vibrancy / dark mode
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
    context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1.0))
    context.setLineCap(.round)
    context.setLineJoin(.round)
    
    // Draw Monogram "L" stroke
    // Canvas: 18x18 pt
    let strokeW: CGFloat = 2.0
    context.setLineWidth(strokeW)
    
    let lStrokePath = CGMutablePath()
    lStrokePath.move(to: CGPoint(x: 4.2, y: 3.8))
    lStrokePath.addLine(to: CGPoint(x: 4.2, y: 14.2))
    lStrokePath.addLine(to: CGPoint(x: 9.8, y: 14.2))
    
    context.addPath(lStrokePath)
    context.strokePath()
    
    // Draw AI Sparkle (✦)
    let sparkCenter = CGPoint(x: 12.8, y: 6.8)
    let sparkSize: CGFloat = 7.6
    let sparkPath = createSparklePath(center: sparkCenter, size: sparkSize, pinch: 0.16)
    
    context.addPath(sparkPath)
    context.fillPath()
    
    return context.makeImage()!
}

func savePNG(image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("Failed to encode PNG for \(url)")
        return
    }
    try? data.write(to: url)
}

// -------------------------------------------------------------
// EXECUTION
// -------------------------------------------------------------
let fileManager = FileManager.default
let outputDir = URL(fileURLWithPath: "scripts/assets")
try? fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("==> Rendering 1024x1024 macOS App Icon...")
let appIcon1024 = renderAppIcon1024()
let masterIconURL = outputDir.appendingPathComponent("AppIcon_1024.png")
savePNG(image: appIcon1024, to: masterIconURL)
print("Saved master icon: \(masterIconURL.path)")

// Create .iconset directory
let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconsetDir)
try? fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let iconSizes: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in iconSizes {
    let destURL = iconsetDir.appendingPathComponent(item.name)
    if item.size == 1024 {
        savePNG(image: appIcon1024, to: destURL)
    } else {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(
            data: nil,
            width: item.size,
            height: item.size,
            bitsPerComponent: 8,
            bytesPerRow: item.size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.interpolationQuality = .high
        ctx.draw(appIcon1024, in: CGRect(x: 0, y: 0, width: item.size, height: item.size))
        if let resized = ctx.makeImage() {
            savePNG(image: resized, to: destURL)
        }
    }
}

// Convert iconset to icns using iconutil
let icnsURL = outputDir.appendingPathComponent("AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
try? task.run()
task.waitUntilExit()

print("==> Created AppIcon.icns (Status: \(task.terminationStatus))")

// Render Menu Bar Icons
print("==> Rendering Menu Bar Icons...")
let mb1x = renderMenuBarIcon(points: 18, scale: 1.0)
let mb2x = renderMenuBarIcon(points: 18, scale: 2.0)
savePNG(image: mb1x, to: outputDir.appendingPathComponent("MenuBarIcon.png"))
savePNG(image: mb2x, to: outputDir.appendingPathComponent("MenuBarIcon@2x.png"))
print("Saved MenuBarIcon.png and MenuBarIcon@2x.png")
