import Foundation

public enum DisplayUnit: String, Codable, Sendable, CaseIterable {
    case hu
    case grams
    case germanStandardDrinks
    case ukUnits
}

public enum Units {
    private static let alcoholDensity = Decimal(sign: .plus, exponent: -1, significand: 8)
    private static let minimumHU = Decimal(sign: .plus, exponent: -1, significand: 5)
    private static let gramsPerStandardDrink = Decimal(10)
    private static let gramsPerUKUnit = Decimal(8)
    private static let estimatedGramsPerHU = Decimal(20)

    public static func grams(volumeMl: Int, abvPercent: Decimal) -> Decimal {
        Decimal(volumeMl) * (abvPercent / Decimal(100)) * alcoholDensity
    }

    public static func estimatedGrams(hu: Decimal) -> Decimal {
        hu * estimatedGramsPerHU
    }

    public static func standardDrinks(grams: Decimal) -> Decimal {
        grams / gramsPerStandardDrink
    }

    public static func ukUnits(grams: Decimal) -> Decimal {
        grams / gramsPerUKUnit
    }

    public static func isValidHU(_ hu: Decimal) -> Bool {
        guard !hu.isNaN, hu >= minimumHU else {
            return false
        }
        let doubled = hu * Decimal(2)
        return doubled == round(doubled, scale: 0)
    }

    public static func value(grams: Decimal, hu: Decimal, in unit: DisplayUnit) -> Decimal {
        switch unit {
        case .hu:
            return hu
        case .grams:
            return grams
        case .germanStandardDrinks:
            return standardDrinks(grams: grams)
        case .ukUnits:
            return ukUnits(grams: grams)
        }
    }

    public static func displayValue(grams: Decimal, hu: Decimal, in unit: DisplayUnit) -> Decimal {
        let raw = value(grams: grams, hu: hu, in: unit)
        switch unit {
        case .hu:
            return raw
        case .grams:
            return round(raw, scale: 0)
        case .germanStandardDrinks, .ukUnits:
            return round(raw, scale: 1)
        }
    }

    private static func round(_ value: Decimal, scale: Int) -> Decimal {
        var source = value
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
