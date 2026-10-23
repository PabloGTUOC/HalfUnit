import Foundation
import SwiftUI

public enum BrandColors {
    // MARK: - Sanzo Wada 263 Raw Palette
    public static let slateHex = "#34454C"
    public static let burntSiennaHex = "#AE5224"
    public static let pinkishCinnamonHex = "#EEB480"
    public static let turquoiseGreenHex = "#B5DECC"
    public static let whiteHex = "#FFFFFF"
    public static let darkBackgroundHex = "#1C1C1E"
    public static let appBackgroundLightHex = "#F9F1ED"
    public static let appBackgroundDarkHex = "#221814"
    public static let cardBackgroundLightHex = "#FDFAF9"
    public static let cardBackgroundDarkHex = "#2B211F"
    public static let secondaryGreyHex = "#6E6E73"

    // MARK: - Color Tokens (Asset Catalog)
    public static let accent = Color("AccentColor")
    public static let brandFill = Color("BrandFill")
    public static let brandInk = Color("BrandInk")
    public static let streakCardBackground = Color("StreakCardBackground")
    public static let streakCardText = Color("StreakCardText")
    public static let highlightBackground = Color("HighlightBackground")
    public static let highlightText = Color("HighlightText")
    public static let chartLow = Color("ChartLow")
    public static let chartHigh = Color("ChartHigh")
    public static let appBackground = Color("AppBackground")
    public static let cardBackground = Color("CardBackground")

    // MARK: - Appearance Hex Specifications
    public struct AppearanceHex: Sendable {
        public let light: String
        public let dark: String

        public init(light: String, dark: String) {
            self.light = light
            self.dark = dark
        }
    }

    public static let accentHex = AppearanceHex(light: burntSiennaHex, dark: pinkishCinnamonHex)
    public static let brandFillHex = AppearanceHex(light: burntSiennaHex, dark: burntSiennaHex)
    public static let brandInkHex = AppearanceHex(light: slateHex, dark: turquoiseGreenHex)
    public static let streakCardBackgroundHex = AppearanceHex(light: turquoiseGreenHex, dark: slateHex)
    public static let streakCardTextHex = AppearanceHex(light: slateHex, dark: turquoiseGreenHex)
    public static let highlightBackgroundHex = AppearanceHex(light: pinkishCinnamonHex, dark: slateHex)
    public static let highlightTextHex = AppearanceHex(light: slateHex, dark: pinkishCinnamonHex)
    public static let chartLowHex = AppearanceHex(light: pinkishCinnamonHex, dark: burntSiennaHex)
    public static let chartHighHex = AppearanceHex(light: burntSiennaHex, dark: pinkishCinnamonHex)
    public static let appBackgroundHex = AppearanceHex(light: appBackgroundLightHex, dark: appBackgroundDarkHex)
    public static let cardBackgroundHex = AppearanceHex(light: cardBackgroundLightHex, dark: cardBackgroundDarkHex)

    // MARK: - WCAG Contrast Calculations
    public static func relativeLuminance(hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else {
            return 0.0
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        func adjust(_ channel: Double) -> Double {
            channel <= 0.04045 ? (channel / 12.92) : pow((channel + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * adjust(r)) + (0.7152 * adjust(g)) + (0.0722 * adjust(b))
    }

    public static func contrastRatio(hex1: String, hex2: String) -> Double {
        let l1 = relativeLuminance(hex: hex1)
        let l2 = relativeLuminance(hex: hex2)
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Heatmap Ramp Interpolation
    // In light: Cinnamon #EEB480 -> Sienna #AE5224
    // In dark: Sienna #AE5224 -> Cinnamon #EEB480
    public static func chartColor(progress: Double) -> Color {
        let clamped = max(0.0, min(1.0, progress))
        #if canImport(UIKit) && !os(watchOS)
            return Color(
                uiColor: UIColor { traits in
                    let isDark = traits.userInterfaceStyle == .dark
                    let startHex = isDark ? burntSiennaHex : pinkishCinnamonHex
                    let endHex = isDark ? pinkishCinnamonHex : burntSiennaHex

                    func rgb(_ h: String) -> (r: Double, g: Double, b: Double) {
                        let c = h.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        guard let val = UInt64(c, radix: 16) else { return (0, 0, 0) }
                        return (
                            Double((val >> 16) & 0xFF) / 255.0, Double((val >> 8) & 0xFF) / 255.0,
                            Double(val & 0xFF) / 255.0
                        )
                    }

                    let s = rgb(startHex)
                    let e = rgb(endHex)
                    let r = s.r + (e.r - s.r) * clamped
                    let g = s.g + (e.g - s.g) * clamped
                    let b = s.b + (e.b - s.b) * clamped

                    return UIColor(red: r, green: g, blue: b, alpha: 1.0)
                }
            )
        #else
            return chartHigh
        #endif
    }
}
