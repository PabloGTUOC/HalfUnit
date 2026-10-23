import Foundation
import HalfUnitCore
import SwiftUI

typealias WatchLocalization = AppLocalization
typealias WatchPresetPresentation = PresetPresentation

enum AppLocalization {
    static func bundle(for locale: Locale) -> Bundle {
        if let languageCode = locale.language.languageCode?.identifier,
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let localizedBundle = Bundle(path: path)
        {
            return localizedBundle
        }
        return .main
    }

    static func string(_ key: String, locale: Locale = .current) -> String {
        bundle(for: locale).localizedString(forKey: key, value: nil, table: nil)
    }

    static func plural(_ key: String, count: Int, locale: Locale = .current) -> String {
        let format = string(key, locale: locale)
        return String(format: format, locale: locale, Int64(count))
    }
}

enum PresetPresentation {
    private static let catalogKeyByPresetKey: [String: String] = [
        "smallBeer": "preset.smallBeer",
        "smallWine": "preset.smallWine",
        "beer": "preset.beer",
        "wineGlass": "preset.wineGlass",
        "shot": "preset.shot",
        "longDrink": "preset.longDrink",
    ]

    private static let symbolByPresetKey: [String: String] = [
        "smallBeer": "halfunit.beer.bottle",
        "smallWine": "halfunit.wine.small",
        "beer": "halfunit.beer.mug",
        "wineGlass": "halfunit.wine.glass",
        "shot": "halfunit.shot",
        "longDrink": "halfunit.longdrink",
    ]

    static func isCustomSymbol(_ symbolName: String) -> Bool {
        symbolName.hasPrefix("halfunit.")
    }

    @ViewBuilder
    static func image(for symbolName: String) -> some View {
        if isCustomSymbol(symbolName) {
            Image(symbolName)
        } else {
            Image(systemName: symbolName)
        }
    }

    static func catalogKey(for presetKey: String?) -> String? {
        guard let presetKey else {
            return nil
        }
        return catalogKeyByPresetKey[presetKey]
    }

    static func localizedName(for preset: Preset, locale: Locale = .current) -> String {
        localizedName(presetKey: preset.key, fallbackName: preset.name, locale: locale)
    }

    static func localizedName(
        presetKey: String?,
        fallbackName: String,
        locale: Locale = .current
    ) -> String {
        let effectiveKey: String?
        if let presetKey {
            effectiveKey = (fallbackName == presetKey || fallbackName.isEmpty) ? presetKey : nil
        } else {
            effectiveKey = catalogKeyByPresetKey[fallbackName] != nil ? fallbackName : nil
        }
        guard let catalogKey = catalogKey(for: effectiveKey) else {
            return fallbackName
        }
        return AppLocalization.string(catalogKey, locale: locale)
    }

    static func symbolName(for preset: Preset) -> String {
        symbolName(presetKey: preset.key, fallbackSymbol: preset.symbolName)
    }

    static func symbolName(presetKey: String?, fallbackSymbol: String) -> String {
        if let presetKey, let mapped = symbolByPresetKey[presetKey] {
            return mapped
        }
        let trimmed = fallbackSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "questionmark" {
            return trimmed
        }
        return "halfunit.wine.glass"
    }

    static func formattedHUNumber(_ hu: Decimal, locale: Locale = .current) -> String {
        hu.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0...1))
        )
    }

    static func formattedHU(_ hu: Decimal, locale: Locale = .current) -> String {
        let numberText = formattedHUNumber(hu, locale: locale)
        let format = AppLocalization.string("unit.huValue", locale: locale)
        return String(format: format, locale: locale, numberText)
    }

    static func formattedDisplayValue(
        grams: Decimal,
        hu: Decimal,
        in unit: DisplayUnit,
        locale: Locale = .current
    ) -> String {
        let rounded = Units.displayValue(grams: grams, hu: hu, in: unit)
        let fractionRange: ClosedRange<Int> =
            switch unit {
            case .grams:
                0...0
            case .hu, .germanStandardDrinks, .ukUnits:
                0...1
            }

        let numberText = rounded.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(fractionRange))
        )

        let formatKey: String =
            switch unit {
            case .hu:
                "unit.huValue"
            case .grams:
                "unit.gramsValue"
            case .germanStandardDrinks:
                "unit.germanStandardDrinksValue"
            case .ukUnits:
                "unit.ukUnitsValue"
            }

        let format = AppLocalization.string(formatKey, locale: locale)
        return String(format: format, locale: locale, numberText)
    }

    static func accessibilityLabel(for preset: Preset, locale: Locale = .current) -> String {
        accessibilityLabel(
            presetKey: preset.key,
            fallbackName: preset.name,
            hu: preset.hu,
            locale: locale
        )
    }

    static func accessibilityLabel(
        presetKey: String?,
        fallbackName: String,
        hu: Decimal,
        locale: Locale = .current
    ) -> String {
        let displayName = localizedName(
            presetKey: presetKey,
            fallbackName: fallbackName,
            locale: locale
        )
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let spokenName = languageCode == "de" ? displayName : displayName.lowercased(with: locale)
        let numberText = formattedHUNumber(hu, locale: locale)

        if hu == Decimal(1) {
            let format = AppLocalization.string("accessibility.logPreset.oneUnit", locale: locale)
            return String(format: format, locale: locale, spokenName)
        }

        let format = AppLocalization.string("accessibility.logPreset.units", locale: locale)
        return String(format: format, locale: locale, spokenName, numberText)
    }
}

public struct PresetSymbolImage: View {
    public let symbolName: String

    public init(_ symbolName: String) {
        self.symbolName = symbolName
    }

    public var body: some View {
        PresetPresentation.image(for: symbolName)
    }
}
