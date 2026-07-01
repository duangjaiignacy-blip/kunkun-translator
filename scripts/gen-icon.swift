import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Foundation

// 困困翻译助手 — App 图标
// 多层渐变 + 高光 + "困"字主标 + 角标"A↔文"暗示翻译

let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: size * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fputs("ctx fail\n", stderr); exit(1) }

let S = CGFloat(size)
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let radius: CGFloat = 224

// ===== 圆角裁剪 =====
ctx.saveGState()
let clipPath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(clipPath)
ctx.clip()

// ===== 主渐变背景：粉紫 → 蓝紫，更年轻 =====
let bgColors = [
    CGColor(srgbRed: 0.99, green: 0.42, blue: 0.78, alpha: 1.0), // 樱花粉
    CGColor(srgbRed: 0.55, green: 0.30, blue: 0.98, alpha: 1.0), // 电光紫
    CGColor(srgbRed: 0.20, green: 0.42, blue: 1.00, alpha: 1.0)  // 深空蓝
]
if let g = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0.0, 0.55, 1.0]) {
    ctx.drawLinearGradient(g,
                           start: CGPoint(x: 0, y: S),
                           end:   CGPoint(x: S, y: 0),
                           options: [])
}

// ===== 顶部高光 =====
let topShine = [
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28),
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
]
if let g2 = CGGradient(colorsSpace: colorSpace, colors: topShine as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(g2,
                           start: CGPoint(x: 0, y: S),
                           end:   CGPoint(x: 0, y: S * 0.48),
                           options: [])
}

// ===== 装饰光斑 =====
ctx.saveGState()
let blob1Colors = [
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.18),
    CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0)
]
if let rg = CGGradient(colorsSpace: colorSpace, colors: blob1Colors as CFArray, locations: [0, 1]) {
    ctx.drawRadialGradient(rg,
                           startCenter: CGPoint(x: S * 0.22, y: S * 0.78),
                           startRadius: 0,
                           endCenter:   CGPoint(x: S * 0.22, y: S * 0.78),
                           endRadius:   S * 0.35,
                           options: [])
}
let blob2Colors = [
    CGColor(srgbRed: 1, green: 0.85, blue: 0.95, alpha: 0.22),
    CGColor(srgbRed: 1, green: 0.85, blue: 0.95, alpha: 0.0)
]
if let rg2 = CGGradient(colorsSpace: colorSpace, colors: blob2Colors as CFArray, locations: [0, 1]) {
    ctx.drawRadialGradient(rg2,
                           startCenter: CGPoint(x: S * 0.85, y: S * 0.22),
                           startRadius: 0,
                           endCenter:   CGPoint(x: S * 0.85, y: S * 0.22),
                           endRadius:   S * 0.32,
                           options: [])
}
ctx.restoreGState()

ctx.restoreGState()
ctx.saveGState()
// 再次裁剪以应用阴影
ctx.addPath(clipPath)
ctx.clip()

// ===== 主字"困" =====
let text = "困" as CFString
let font = CTFontCreateWithName("PingFangSC-Heavy" as CFString, 600, nil)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: white
]
let attrStr = CFAttributedStringCreate(nil, text, attrs as CFDictionary)!
let line = CTLineCreateWithAttributedString(attrStr)
let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
let tx = (S - bounds.width) / 2 - bounds.minX
let ty = (S - bounds.height) / 2 - bounds.minY - S * 0.02

ctx.setShadow(offset: CGSize(width: 0, height: -18),
              blur: 36,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.32))
ctx.textPosition = CGPoint(x: tx, y: ty)
CTLineDraw(line, ctx)
ctx.restoreGState()

// ===== 角标：右下角小气泡 "译" 暗示翻译 =====
ctx.saveGState()
let badgeSize: CGFloat = S * 0.30
let badgeOrigin = CGPoint(x: S - badgeSize - S * 0.07, y: S * 0.07)
let badgeRect = CGRect(x: badgeOrigin.x, y: badgeOrigin.y, width: badgeSize, height: badgeSize)
let badgePath = CGPath(ellipseIn: badgeRect, transform: nil)

ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18,
              color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25))
ctx.addPath(badgePath)
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.96))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
let badgeText = "译" as CFString
let badgeFont = CTFontCreateWithName("PingFangSC-Heavy" as CFString, badgeSize * 0.62, nil)
let badgeColor = CGColor(srgbRed: 0.45, green: 0.20, blue: 0.95, alpha: 1.0)
let bAttrs: [CFString: Any] = [
    kCTFontAttributeName: badgeFont,
    kCTForegroundColorAttributeName: badgeColor
]
let bAttrStr = CFAttributedStringCreate(nil, badgeText, bAttrs as CFDictionary)!
let bLine = CTLineCreateWithAttributedString(bAttrStr)
let bBounds = CTLineGetBoundsWithOptions(bLine, .useGlyphPathBounds)
let bx = badgeOrigin.x + (badgeSize - bBounds.width) / 2 - bBounds.minX
let by = badgeOrigin.y + (badgeSize - bBounds.height) / 2 - bBounds.minY
ctx.textPosition = CGPoint(x: bx, y: by)
CTLineDraw(bLine, ctx)
ctx.restoreGState()

// ===== 输出 PNG =====
guard let cgImage = ctx.makeImage() else { exit(1) }
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let outURL = URL(fileURLWithPath: outPath) as CFURL
let utType = UTType.png.identifier as CFString
guard let dest = CGImageDestinationCreateWithURL(outURL, utType, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, cgImage, nil)
if !CGImageDestinationFinalize(dest) { fputs("png save fail\n", stderr); exit(1) }
print("✓ Wrote \(outPath)")
