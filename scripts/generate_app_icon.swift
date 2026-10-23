import CoreGraphics
import Foundation
import ImageIO

struct IconVariant {
    let filename: String
    let backgroundColor: CGColor
    let liquidColor: CGColor
    let outlineColor: CGColor
    let isWatch: Bool
}

func sRGBColor(r: Int, g: Int, b: Int) -> CGColor {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let components: [CGFloat] = [
        CGFloat(r) / 255.0,
        CGFloat(g) / 255.0,
        CGFloat(b) / 255.0,
        1.0,
    ]
    return CGColor(colorSpace: colorSpace, components: components)!
}

func sRGBColor(hex: String) -> CGColor {
    var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if str.hasPrefix("#") {
        str.removeFirst()
    }
    let scanner = Scanner(string: str)
    var hexNumber: UInt64 = 0
    scanner.scanHexInt64(&hexNumber)
    let r = Int((hexNumber >> 16) & 0xFF)
    let g = Int((hexNumber >> 8) & 0xFF)
    let b = Int(hexNumber & 0xFF)
    return sRGBColor(r: r, g: g, b: b)
}

func makeBottlePath() -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 452, y: 180))
    path.addLine(to: CGPoint(x: 572, y: 180))
    path.addLine(to: CGPoint(x: 572, y: 370))
    path.addCurve(
        to: CGPoint(x: 652, y: 490),
        control1: CGPoint(x: 572, y: 410),
        control2: CGPoint(x: 652, y: 430)
    )
    path.addLine(to: CGPoint(x: 652, y: 820))
    path.addQuadCurve(to: CGPoint(x: 622, y: 850), control: CGPoint(x: 652, y: 850))
    path.addLine(to: CGPoint(x: 402, y: 850))
    path.addQuadCurve(to: CGPoint(x: 372, y: 820), control: CGPoint(x: 372, y: 850))
    path.addLine(to: CGPoint(x: 372, y: 490))
    path.addCurve(
        to: CGPoint(x: 452, y: 370),
        control1: CGPoint(x: 372, y: 430),
        control2: CGPoint(x: 452, y: 410)
    )
    path.closeSubpath()
    return path
}

func renderIcon(variant: IconVariant, destinationURL: URL) {
    let size = 1024
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    guard
        let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else {
        fatalError("Failed to create CGContext for \(variant.filename)")
    }

    // Set up coordinate system: (0, 0) at top-left, y pointing down
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: 1.0, y: -1.0)

    // Full-bleed background
    context.setFillColor(variant.backgroundColor)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))

    let bottlePath = makeBottlePath()

    // Render glyph (bottle + liquid)
    context.saveGState()

    if variant.isWatch {
        // Glyphed scaled 0.8 around centre and shifted to be optically centred in circular mask:
        // translate(512 512) scale(0.8) translate(-512 -515)
        var transform = CGAffineTransform.identity
        transform = transform.translatedBy(x: 512, y: 512)
        transform = transform.scaledBy(x: 0.8, y: 0.8)
        transform = transform.translatedBy(x: -512, y: -515)
        context.concatenate(transform)
    }

    // Liquid: rectangle x 340...684, y 640...880 clipped to P, filled
    context.saveGState()
    context.addPath(bottlePath)
    context.clip()
    context.setFillColor(variant.liquidColor)
    context.fill(CGRect(x: 340, y: 640, width: 684 - 340, height: 880 - 640))
    context.restoreGState()

    // Outline: P stroked, width 36, round line join, no fill
    context.setLineWidth(36)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(variant.outlineColor)
    context.addPath(bottlePath)
    context.strokePath()

    context.restoreGState()

    guard let cgImage = context.makeImage() else {
        fatalError("Failed to create CGImage for \(variant.filename)")
    }

    guard
        let destination = CGImageDestinationCreateWithURL(
            destinationURL as CFURL,
            "public.png" as CFString,
            1,
            nil
        )
    else {
        fatalError("Failed to create CGImageDestination for \(destinationURL.path)")
    }

    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Failed to finalize image destination for \(destinationURL.path)")
    }

    print("Generated \(destinationURL.lastPathComponent)")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDir = repoRoot.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let variants: [IconVariant] = [
    // iOS light (any appearance): background Pinkish Cinnamon #EEB480, liquid Burnt Sienna #AE5224, outline Slate #34454C
    IconVariant(
        filename: "ios-light.png",
        backgroundColor: sRGBColor(hex: "EEB480"),
        liquidColor: sRGBColor(hex: "AE5224"),
        outlineColor: sRGBColor(hex: "34454C"),
        isWatch: false
    ),
    // iOS dark (luminosity dark): background #221814, liquid #AE5224, outline #EEB480
    IconVariant(
        filename: "ios-dark.png",
        backgroundColor: sRGBColor(hex: "221814"),
        liquidColor: sRGBColor(hex: "AE5224"),
        outlineColor: sRGBColor(hex: "EEB480"),
        isWatch: false
    ),
    // iOS tinted (luminosity tinted): background solid black #000000, liquid #8C8C8C (55% grey), outline #FFFFFF
    IconVariant(
        filename: "ios-tinted.png",
        backgroundColor: sRGBColor(hex: "000000"),
        liquidColor: sRGBColor(hex: "8C8C8C"),
        outlineColor: sRGBColor(hex: "FFFFFF"),
        isWatch: false
    ),
    // watchOS: same as iOS light, scaled 0.8 around centre and shifted to optically centre
    IconVariant(
        filename: "watch.png",
        backgroundColor: sRGBColor(hex: "EEB480"),
        liquidColor: sRGBColor(hex: "AE5224"),
        outlineColor: sRGBColor(hex: "34454C"),
        isWatch: true
    ),
]

for variant in variants {
    let destURL = outputDir.appendingPathComponent(variant.filename)
    renderIcon(variant: variant, destinationURL: destURL)
}

print("All app icons generated successfully.")
