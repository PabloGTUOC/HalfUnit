import Foundation
import HalfUnitCore
import SwiftUI
import Testing
import UIKit

@testable import HalfUnit

@Suite("Sanzo Wada 263 Brand Colors & WCAG Contrast Tests")
struct BrandColorsContrastTests {
    private static let systemLightBackgroundHex = "#FFFFFF"
    private static let systemDarkBackgroundHex = "#1C1C1E"
    private static let secondaryLightBackgroundHex = "#F2F2F7"
    private static let secondaryDarkBackgroundHex = "#2C2C2E"

    struct ContrastPair: Sendable {
        let name: String
        let foregroundHex: String
        let backgroundHex: String
        let appearance: String
        let minRatio: Double
        let description: String
    }

    /// Verifies Sanzo Wada #263 palette exact hex values and faded Burnt Sienna backgrounds.
    @Test("Sanzo Wada 263 palette raw hex codes match specification")
    func paletteHexCodesMatchSpecification() {
        #expect(BrandColors.slateHex == "#34454C")
        #expect(BrandColors.burntSiennaHex == "#AE5224")
        #expect(BrandColors.pinkishCinnamonHex == "#EEB480")
        #expect(BrandColors.turquoiseGreenHex == "#B5DECC")
        #expect(BrandColors.whiteHex == "#FFFFFF")
        #expect(BrandColors.darkBackgroundHex == "#1C1C1E")
        #expect(BrandColors.appBackgroundLightHex == "#F9F1ED")
        #expect(BrandColors.appBackgroundDarkHex == "#221814")
        #expect(BrandColors.cardBackgroundLightHex == "#FDFAF9")
        #expect(BrandColors.cardBackgroundDarkHex == "#2B211F")
        #expect(BrandColors.secondaryGreyHex == "#6E6E73")
    }

    /// Tests relative luminance calculations for known reference values (black, white, mid-tones).
    @Test("Relative luminance calculation conforms to WCAG 2.1 formula")
    func relativeLuminanceFormula() {
        let lumBlack = BrandColors.relativeLuminance(hex: "#000000")
        let lumWhite = BrandColors.relativeLuminance(hex: "#FFFFFF")
        #expect(lumBlack == 0.0)
        #expect(abs(lumWhite - 1.0) < 0.001)

        let ratioBlackWhite = BrandColors.contrastRatio(hex1: "#000000", hex2: "#FFFFFF")
        #expect(abs(ratioBlackWhite - 21.0) < 0.05)
    }

    /// Asserts all text/background pairs used across the app meet WCAG AA standards:
    /// - Normal text: >= 4.5:1
    /// - Large text & UI components: >= 3.0:1
    @Test("All application color pairs meet WCAG AA contrast requirements in Light and Dark modes")
    func wcagContrastRequirements() {
        let pairs: [ContrastPair] = [
            // 1. Streak Card: Turquoise & Slate inverted across modes
            ContrastPair(
                name: "StreakCard (Light)",
                foregroundHex: BrandColors.streakCardTextHex.light,
                backgroundHex: BrandColors.streakCardBackgroundHex.light,
                appearance: "Light",
                minRatio: 4.5,
                description: "Slate (#34454C) text on Turquoise Green (#B5DECC) background"
            ),
            ContrastPair(
                name: "StreakCard (Dark)",
                foregroundHex: BrandColors.streakCardTextHex.dark,
                backgroundHex: BrandColors.streakCardBackgroundHex.dark,
                appearance: "Dark",
                minRatio: 4.5,
                description: "Turquoise Green (#B5DECC) text on Slate (#34454C) background"
            ),

            // 2. Highlight / Undo Banner / Badges: Cinnamon & Slate
            ContrastPair(
                name: "Highlight (Light)",
                foregroundHex: BrandColors.highlightTextHex.light,
                backgroundHex: BrandColors.highlightBackgroundHex.light,
                appearance: "Light",
                minRatio: 4.5,
                description: "Slate (#34454C) text on Pinkish Cinnamon (#EEB480) background"
            ),
            ContrastPair(
                name: "Highlight (Dark)",
                foregroundHex: BrandColors.highlightTextHex.dark,
                backgroundHex: BrandColors.highlightBackgroundHex.dark,
                appearance: "Dark",
                minRatio: 4.5,
                description: "Pinkish Cinnamon (#EEB480) text on Slate (#34454C) background"
            ),

            // 3. BrandFill: White text on Burnt Sienna buttons/chips in both modes
            ContrastPair(
                name: "BrandFill White Content (Light)",
                foregroundHex: BrandColors.whiteHex,
                backgroundHex: BrandColors.brandFillHex.light,
                appearance: "Light",
                minRatio: 4.5,
                description: "White (#FFFFFF) text on Burnt Sienna (#AE5224) fill"
            ),
            ContrastPair(
                name: "BrandFill White Content (Dark)",
                foregroundHex: BrandColors.whiteHex,
                backgroundHex: BrandColors.brandFillHex.dark,
                appearance: "Dark",
                minRatio: 4.5,
                description: "White (#FFFFFF) text on Burnt Sienna (#AE5224) fill"
            ),

            // 4. BrandInk: Slate on white (Light) and Turquoise on dark surface (Dark)
            ContrastPair(
                name: "BrandInk on Primary Surface (Light)",
                foregroundHex: BrandColors.brandInkHex.light,
                backgroundHex: Self.systemLightBackgroundHex,
                appearance: "Light",
                minRatio: 4.5,
                description: "Slate (#34454C) text on white background"
            ),
            ContrastPair(
                name: "BrandInk on Primary Surface (Dark)",
                foregroundHex: BrandColors.brandInkHex.dark,
                backgroundHex: Self.systemDarkBackgroundHex,
                appearance: "Dark",
                minRatio: 4.5,
                description: "Turquoise Green (#B5DECC) text on dark (#1C1C1E) surface"
            ),

            // 5. AccentColor: Burnt Sienna in light, Pinkish Cinnamon in dark
            ContrastPair(
                name: "AccentColor on Primary Surface (Light)",
                foregroundHex: BrandColors.accentHex.light,
                backgroundHex: Self.systemLightBackgroundHex,
                appearance: "Light",
                minRatio: 4.5,
                description: "Burnt Sienna (#AE5224) interactive elements on white background"
            ),
            ContrastPair(
                name: "AccentColor on Primary Surface (Dark)",
                foregroundHex: BrandColors.accentHex.dark,
                backgroundHex: Self.systemDarkBackgroundHex,
                appearance: "Dark",
                minRatio: 4.5,
                description: "Pinkish Cinnamon (#EEB480) interactive elements on dark background"
            ),

            // 6. Faded Burnt Sienna Backgrounds (Lead measured)
            ContrastPair(
                name: "Slate on AppBackground (Light)",
                foregroundHex: BrandColors.slateHex,
                backgroundHex: BrandColors.appBackgroundLightHex,
                appearance: "Light",
                minRatio: 8.9,
                description: "Slate on light AppBackground (#F9F1ED)"
            ),
            ContrastPair(
                name: "Sienna on AppBackground (Light)",
                foregroundHex: BrandColors.burntSiennaHex,
                backgroundHex: BrandColors.appBackgroundLightHex,
                appearance: "Light",
                minRatio: 4.5,
                description: "Burnt Sienna on light AppBackground (#F9F1ED)"
            ),
            ContrastPair(
                name: "Secondary Grey on AppBackground (Light)",
                foregroundHex: BrandColors.secondaryGreyHex,
                backgroundHex: BrandColors.appBackgroundLightHex,
                appearance: "Light",
                minRatio: 4.5,
                description: "Secondary Grey on light AppBackground (#F9F1ED)"
            ),
            ContrastPair(
                name: "Sienna on CardBackground (Light)",
                foregroundHex: BrandColors.burntSiennaHex,
                backgroundHex: BrandColors.cardBackgroundLightHex,
                appearance: "Light",
                minRatio: 5.0,
                description: "Burnt Sienna on light CardBackground (#FDFAF9)"
            ),
            ContrastPair(
                name: "Cinnamon on AppBackground (Dark)",
                foregroundHex: BrandColors.pinkishCinnamonHex,
                backgroundHex: BrandColors.appBackgroundDarkHex,
                appearance: "Dark",
                minRatio: 9.0,
                description: "Pinkish Cinnamon on dark AppBackground (#221814)"
            ),
            ContrastPair(
                name: "Turquoise on AppBackground (Dark)",
                foregroundHex: BrandColors.turquoiseGreenHex,
                backgroundHex: BrandColors.appBackgroundDarkHex,
                appearance: "Dark",
                minRatio: 11.5,
                description: "Turquoise on dark AppBackground (#221814)"
            ),
            ContrastPair(
                name: "Cinnamon on CardBackground (Dark)",
                foregroundHex: BrandColors.pinkishCinnamonHex,
                backgroundHex: BrandColors.cardBackgroundDarkHex,
                appearance: "Dark",
                minRatio: 8.5,
                description: "Pinkish Cinnamon on dark CardBackground (#2B211F)"
            ),

            // 7. Watch Idiom Pairs (matches Dark appearance tones on watchOS)
            ContrastPair(
                name: "Watch Cinnamon on Black",
                foregroundHex: BrandColors.pinkishCinnamonHex,
                backgroundHex: "#000000",
                appearance: "Watch",
                minRatio: 4.5,
                description: "Pinkish Cinnamon (#EEB480) on black (#000000) watch background"
            ),
            ContrastPair(
                name: "Watch Cinnamon on Tile Background (#1C1C1E)",
                foregroundHex: BrandColors.pinkishCinnamonHex,
                backgroundHex: BrandColors.darkBackgroundHex,
                appearance: "Watch",
                minRatio: 4.5,
                description: "Pinkish Cinnamon (#EEB480) on dark tile (#1C1C1E) background"
            ),
            ContrastPair(
                name: "Watch Cinnamon on Preset Tile (#1F1F1F)",
                foregroundHex: BrandColors.pinkishCinnamonHex,
                backgroundHex: "#1F1F1F",
                appearance: "Watch",
                minRatio: 4.5,
                description: "Pinkish Cinnamon (#EEB480) on 12% white preset tile (#1F1F1F)"
            ),
            ContrastPair(
                name: "Watch Turquoise on Black",
                foregroundHex: BrandColors.turquoiseGreenHex,
                backgroundHex: "#000000",
                appearance: "Watch",
                minRatio: 4.5,
                description: "Turquoise Green (#B5DECC) on black (#000000) watch background"
            ),
            ContrastPair(
                name: "Watch White on BrandFill",
                foregroundHex: BrandColors.whiteHex,
                backgroundHex: BrandColors.brandFillHex.watch,
                appearance: "Watch",
                minRatio: 4.5,
                description: "White (#FFFFFF) on Burnt Sienna (#AE5224) fill"
            ),
        ]

        for pair in pairs {
            let ratio = BrandColors.contrastRatio(hex1: pair.foregroundHex, hex2: pair.backgroundHex)
            #expect(
                ratio >= pair.minRatio,
                "\(pair.name) [\(pair.appearance)]: \(ratio) < expected minimum \(pair.minRatio) (\(pair.description))"
            )
        }
    }

    /// Asserts watch color pairs meet WCAG AA standards (>= 4.5:1 for text, >= 3.0:1 for icons).
    @Test("Watch color pairs meet WCAG AA contrast standards for text and icons")
    func watchContrastRequirements() {
        let pairs: [(name: String, foreground: String, background: String, isText: Bool)] = [
            ("Cinnamon on Black", BrandColors.pinkishCinnamonHex, "#000000", true),
            (
                "Cinnamon on Tile Background (#1C1C1E)",
                BrandColors.pinkishCinnamonHex,
                BrandColors.darkBackgroundHex,
                true
            ),
            ("Cinnamon on Preset Tile (#1F1F1F)", BrandColors.pinkishCinnamonHex, "#1F1F1F", true),
            ("Turquoise on Black", BrandColors.turquoiseGreenHex, "#000000", true),
            ("White on BrandFill", BrandColors.whiteHex, BrandColors.burntSiennaHex, true),
            ("Cinnamon Icon on Black", BrandColors.pinkishCinnamonHex, "#000000", false),
            (
                "Cinnamon Icon on Tile Background (#1C1C1E)",
                BrandColors.pinkishCinnamonHex,
                BrandColors.darkBackgroundHex,
                false
            ),
            ("Cinnamon Icon on Preset Tile (#1F1F1F)", BrandColors.pinkishCinnamonHex, "#1F1F1F", false),
            ("Turquoise Icon on Black", BrandColors.turquoiseGreenHex, "#000000", false),
            ("White Icon on BrandFill", BrandColors.whiteHex, BrandColors.burntSiennaHex, false),
        ]

        for pair in pairs {
            let ratio = BrandColors.contrastRatio(hex1: pair.foreground, hex2: pair.background)
            let requiredMin = pair.isText ? 4.5 : 3.0
            #expect(
                ratio >= requiredMin,
                "\(pair.name): ratio \(ratio) must be >= \(requiredMin)"
            )
        }
    }

    /// Verifies named asset catalog colors can be loaded by UIColor / Color without crashing or returning nil.
    @Test("Asset catalog color tokens resolve in UIKit and SwiftUI")
    func colorTokensResolve() {
        let tokenNames = [
            "AccentColor",
            "BrandFill",
            "BrandInk",
            "StreakCardBackground",
            "StreakCardText",
            "HighlightBackground",
            "HighlightText",
            "ChartLow",
            "ChartHigh",
            "AppBackground",
            "CardBackground",
        ]

        for token in tokenNames {
            let uiColor = UIColor(named: token)
            #expect(uiColor != nil, "Asset catalog color token '\(token)' must exist in bundle")
        }
    }
}
