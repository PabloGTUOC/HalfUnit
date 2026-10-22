import Foundation

public enum IntentLocalization {
    private static let sentinel = "__HALF_UNIT_MISSING_KEY__"

    private static let catalogKeyByPresetKey: [String: String] = [
        "smallBeer": "preset.smallBeer",
        "smallWine": "preset.smallWine",
        "beer": "preset.beer",
        "wineGlass": "preset.wineGlass",
        "shot": "preset.shot",
        "longDrink": "preset.longDrink",
    ]

    private static let symbolByPresetKey: [String: String] = [
        "smallBeer": "mug",
        "smallWine": "wineglass",
        "beer": "mug.fill",
        "wineGlass": "wineglass.fill",
        "shot": "cup.and.saucer",
        "longDrink": "takeoutbag.and.cup.and.straw",
    ]

    private static let englishFallbackStrings: [String: String] = [
        "preset.smallBeer": "Small beer",
        "preset.smallWine": "Small wine",
        "preset.beer": "Beer",
        "preset.wineGlass": "Wine glass",
        "preset.shot": "Shot",
        "preset.longDrink": "Long drink",
        "unit.huValue": "%@ HU",
        "intent.logDrink.result": "Logged %1$@ (%2$@).",
        "intent.getStreak.result.drinkingToday": "Drink logged today.",
        "intent.getStreak.result.drinkingTodayWithPrevious": "Drink logged today. %@.",
        "intent.getStats.result.days": "%1$lld of %2$lld days with alcohol (%3$@, %4$@ total).",
        "intent.getStats.result.trackedDays": "%1$lld of %2$lld tracked days with alcohol (%3$@, %4$@ total).",
    ]

    private static let germanFallbackStrings: [String: String] = [
        "preset.smallBeer": "Kleines Bier",
        "preset.smallWine": "Kleiner Wein",
        "preset.beer": "Bier",
        "preset.wineGlass": "Glas Wein",
        "preset.shot": "Schnaps",
        "preset.longDrink": "Longdrink",
        "unit.huValue": "%@ HU",
        "intent.logDrink.result": "%1$@ protokolliert (%2$@).",
        "intent.getStreak.result.drinkingToday": "Heute ein Getränk protokolliert.",
        "intent.getStreak.result.drinkingTodayWithPrevious": "Heute ein Getränk protokolliert. %@.",
        "intent.getStats.result.days": "%1$lld von %2$lld Tagen mit Alkohol (%3$@, %4$@ gesamt).",
        "intent.getStats.result.trackedDays":
            "%1$lld von %2$lld erfassten Tagen mit Alkohol (%3$@, %4$@ gesamt).",
    ]

    public static func bundle(for locale: Locale) -> Bundle {
        if let languageCode = locale.language.languageCode?.identifier,
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let localizedBundle = Bundle(path: path)
        {
            return localizedBundle
        }
        return .main
    }

    public static func string(_ key: String, locale: Locale = .current) -> String {
        let targetBundle = bundle(for: locale)
        let resolved = targetBundle.localizedString(forKey: key, value: sentinel, table: nil)
        if resolved != sentinel && resolved != key {
            return resolved
        }

        let languageCode = locale.language.languageCode?.identifier ?? "en"
        if languageCode == "de", let deValue = germanFallbackStrings[key] {
            return deValue
        }
        if let enValue = englishFallbackStrings[key] {
            return enValue
        }
        return key
    }

    public static func plural(_ key: String, count: Int, locale: Locale = .current) -> String {
        let targetBundle = bundle(for: locale)
        let resolvedFormat = targetBundle.localizedString(forKey: key, value: sentinel, table: nil)
        if resolvedFormat != sentinel && resolvedFormat != key {
            return String(format: resolvedFormat, locale: locale, Int64(count))
        }

        let isGerman = (locale.language.languageCode?.identifier == "de")
        switch key {
        case "streak.daysWithoutAlcohol":
            if isGerman {
                return count == 1 ? "1 Tag ohne Alkohol" : "\(count) Tage ohne Alkohol"
            }
            return count == 1 ? "1 day without alcohol" : "\(count) days without alcohol"
        case "streak.previousStreak":
            if isGerman {
                return count == 1 ? "Vorherige Serie: 1 Tag" : "Vorherige Serie: \(count) Tage"
            }
            return count == 1 ? "Previous streak: 1 day" : "Previous streak: \(count) days"
        case "insights.summary.alcoholFreeDays.value":
            if isGerman {
                return count == 1 ? "1 alkoholfreier Tag" : "\(count) alkoholfreie Tage"
            }
            return count == 1 ? "1 alcohol-free day" : "\(count) alcohol-free days"
        default:
            return "\(count)"
        }
    }

    public static func localizedPresetName(
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
        guard let effectiveKey, let catalogKey = catalogKeyByPresetKey[effectiveKey] else {
            return fallbackName
        }
        return string(catalogKey, locale: locale)
    }

    public static func symbolName(presetKey: String?, fallbackSymbol: String) -> String {
        let trimmed = fallbackSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "questionmark" {
            return trimmed
        }
        if let presetKey, let mapped = symbolByPresetKey[presetKey] {
            return mapped
        }
        return trimmed.isEmpty ? "wineglass" : trimmed
    }

    public static func formattedHUNumber(_ hu: Decimal, locale: Locale = .current) -> String {
        hu.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0...1))
        )
    }

    public static func formattedHU(_ hu: Decimal, locale: Locale = .current) -> String {
        let numberText = formattedHUNumber(hu, locale: locale)
        let format = string("unit.huValue", locale: locale)
        return String(format: format, locale: locale, numberText)
    }
}
