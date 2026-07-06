import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Foundation

// 困困翻译助手 — App 图标
// 黑色圆角底 + 白色外框 + 蓝色聊天气泡，参考翻译类工具图标的清晰隐喻，但不做原样复刻。

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
let outerRadius: CGFloat = 232
let inset: CGFloat = 62
let innerRect = rect.insetBy(dx: inset, dy: inset)
let innerRadius: CGFloat = 176

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fillLinearGradient(in path: CGPath, colors: [CGColor], locations: [CGFloat], start: CGPoint, end: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    }
    ctx.restoreGState()
}

func drawText(_ text: CFString, fontSize: CGFloat, color: CGColor, center: CGPoint, name: CFString = "AvenirNext-DemiBold" as CFString) {
    let font = CTFontCreateWithName(name, fontSize, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color
    ]
    let attrStr = CFAttributedStringCreate(nil, text, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let x = center.x - bounds.width / 2 - bounds.minX
    let y = center.y - bounds.height / 2 - bounds.minY
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

func drawSpeechBubble(rect bubbleRect: CGRect,
                      radius: CGFloat,
                      tailX: CGFloat,
                      tailWidth: CGFloat,
                      tailHeight: CGFloat,
                      colors: [CGColor]) {
    let minX = bubbleRect.minX
    let maxX = bubbleRect.maxX
    let minY = bubbleRect.minY
    let maxY = bubbleRect.maxY
    let r = min(radius, bubbleRect.width / 2, bubbleRect.height / 2)

    let path = CGMutablePath()
    path.move(to: CGPoint(x: minX + r, y: minY))
    path.addLine(to: CGPoint(x: tailX - tailWidth * 0.45, y: minY))
    path.addCurve(to: CGPoint(x: tailX + tailWidth * 0.18, y: minY - tailHeight),
                  control1: CGPoint(x: tailX - tailWidth * 0.10, y: minY - tailHeight * 0.08),
                  control2: CGPoint(x: tailX + tailWidth * 0.06, y: minY - tailHeight * 0.72))
    path.addCurve(to: CGPoint(x: tailX + tailWidth * 0.46, y: minY),
                  control1: CGPoint(x: tailX + tailWidth * 0.28, y: minY - tailHeight * 0.42),
                  control2: CGPoint(x: tailX + tailWidth * 0.42, y: minY - tailHeight * 0.12))
    path.addLine(to: CGPoint(x: maxX - r, y: minY))
    path.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
    path.addLine(to: CGPoint(x: maxX, y: maxY - r))
    path.addQuadCurve(to: CGPoint(x: maxX - r, y: maxY), control: CGPoint(x: maxX, y: maxY))
    path.addLine(to: CGPoint(x: minX + r, y: maxY))
    path.addQuadCurve(to: CGPoint(x: minX, y: maxY - r), control: CGPoint(x: minX, y: maxY))
    path.addLine(to: CGPoint(x: minX, y: minY + r))
    path.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
    path.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14),
                  blur: 24,
                  color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.34))
    fillLinearGradient(in: path,
                       colors: colors,
                       locations: [0, 1],
                       start: CGPoint(x: bubbleRect.minX, y: bubbleRect.maxY),
                       end: CGPoint(x: bubbleRect.maxX, y: bubbleRect.minY))
    ctx.restoreGState()
}

// ===== 外框与底色 =====
ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
ctx.addPath(roundedRect(rect, outerRadius))
ctx.fillPath()

let innerPath = roundedRect(innerRect, innerRadius)
fillLinearGradient(
    in: innerPath,
    colors: [
        CGColor(srgbRed: 0.04, green: 0.05, blue: 0.08, alpha: 1.0),
        CGColor(srgbRed: 0.06, green: 0.07, blue: 0.11, alpha: 1.0)
    ],
    locations: [0, 1],
    start: CGPoint(x: 0, y: S),
    end: CGPoint(x: S, y: 0)
)

// ===== 气泡 =====
let leftBubble = CGRect(x: S * 0.24, y: S * 0.38, width: S * 0.34, height: S * 0.24)
drawSpeechBubble(
    rect: leftBubble,
    radius: S * 0.055,
    tailX: leftBubble.minX + leftBubble.width * 0.62,
    tailWidth: S * 0.12,
    tailHeight: S * 0.105,
    colors: [
        CGColor(srgbRed: 0.22, green: 0.35, blue: 0.95, alpha: 1.0),
        CGColor(srgbRed: 0.38, green: 0.57, blue: 0.98, alpha: 1.0)
    ]
)

let rightBubble = CGRect(x: S * 0.43, y: S * 0.50, width: S * 0.35, height: S * 0.25)
drawSpeechBubble(
    rect: rightBubble,
    radius: S * 0.06,
    tailX: rightBubble.minX + rightBubble.width * 0.40,
    tailWidth: S * 0.11,
    tailHeight: S * 0.095,
    colors: [
        CGColor(srgbRed: 0.24, green: 0.62, blue: 0.95, alpha: 1.0),
        CGColor(srgbRed: 0.33, green: 0.72, blue: 0.98, alpha: 1.0)
    ]
)

// ===== 字符与星光 =====
let white = CGColor(srgbRed: 0.96, green: 0.98, blue: 1.0, alpha: 1.0)
let leftText = "A" as CFString
drawText(leftText,
         fontSize: S * 0.15,
         color: white,
         center: CGPoint(x: leftBubble.midX - S * 0.035, y: leftBubble.midY + S * 0.008))

let rightText = "译" as CFString
drawText(rightText,
         fontSize: S * 0.12,
         color: white,
         center: CGPoint(x: rightBubble.midX + S * 0.060, y: rightBubble.midY - S * 0.020),
         name: "PingFangSC-Semibold" as CFString)

ctx.saveGState()
ctx.setStrokeColor(white)
ctx.setLineWidth(S * 0.012)
ctx.setLineCap(.round)
let sparkleCenter = CGPoint(x: rightBubble.minX + rightBubble.width * 0.22, y: rightBubble.minY + rightBubble.height * 0.76)
ctx.move(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y - S * 0.034))
ctx.addLine(to: CGPoint(x: sparkleCenter.x, y: sparkleCenter.y + S * 0.034))
ctx.move(to: CGPoint(x: sparkleCenter.x - S * 0.034, y: sparkleCenter.y))
ctx.addLine(to: CGPoint(x: sparkleCenter.x + S * 0.034, y: sparkleCenter.y))
ctx.strokePath()

ctx.setLineWidth(S * 0.008)
let smallSpark = CGPoint(x: sparkleCenter.x - S * 0.052, y: sparkleCenter.y + S * 0.064)
ctx.move(to: CGPoint(x: smallSpark.x, y: smallSpark.y - S * 0.020))
ctx.addLine(to: CGPoint(x: smallSpark.x, y: smallSpark.y + S * 0.020))
ctx.move(to: CGPoint(x: smallSpark.x - S * 0.020, y: smallSpark.y))
ctx.addLine(to: CGPoint(x: smallSpark.x + S * 0.020, y: smallSpark.y))
ctx.strokePath()
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
