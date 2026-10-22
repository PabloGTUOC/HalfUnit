import Foundation
import Testing

@testable import HalfUnitCore

@Suite("Units Tests")
struct UnitsTests {
    private static func dec(_ string: String) -> Decimal {
        guard let value = Decimal(string: string) else {
            preconditionFailure("Invalid decimal string: \(string)")
        }
        return value
    }

    @Test(
        "Grams calculation for default presets",
        arguments: [
            (330, "5", "13.2"),
            (125, "12", "12"),
            (500, "5", "20"),
            (200, "12", "19.2"),
            (40, "40", "12.8"),
            (80, "40", "25.6"),
        ]
    )
    func gramsForPresetValues(volumeMl: Int, abv: String, expectedGrams: String) {
        let actual = Units.grams(volumeMl: volumeMl, abvPercent: Self.dec(abv))
        #expect(actual == Self.dec(expectedGrams))
    }

    @Test("Standard drinks and UK units conversion")
    func standardDrinksAndUKUnits() {
        #expect(Units.standardDrinks(grams: Decimal(20)) == Decimal(2))
        #expect(Units.standardDrinks(grams: Self.dec("19.2")) == Self.dec("1.92"))
        #expect(Units.ukUnits(grams: Decimal(20)) == Self.dec("2.5"))
        #expect(Units.ukUnits(grams: Self.dec("12.8")) == Self.dec("1.6"))
    }

    @Test(
        "isValidHU validates positive multiples of 0.5",
        arguments: [
            ("0", false),
            ("0.25", false),
            ("0.5", true),
            ("1", true),
            ("1.5", true),
            ("1.75", false),
            ("-0.5", false),
            ("-1", false),
            ("2", true),
            ("10.5", true),
        ]
    )
    func isValidHU(input: String, expected: Bool) {
        #expect(Units.isValidHU(Self.dec(input)) == expected)
    }

    @Test("isValidHU rejects NaN")
    func isValidHUNaN() {
        #expect(!Units.isValidHU(Decimal.nan))
    }

    @Test("Unrounded value for each display unit")
    func unroundedValue() {
        let grams = Self.dec("19.2")
        let hu = Self.dec("1.5")

        #expect(Units.value(grams: grams, hu: hu, in: .hu) == Self.dec("1.5"))
        #expect(Units.value(grams: grams, hu: hu, in: .grams) == Self.dec("19.2"))
        #expect(Units.value(grams: grams, hu: hu, in: .germanStandardDrinks) == Self.dec("1.92"))
        #expect(Units.value(grams: grams, hu: hu, in: .ukUnits) == Self.dec("2.4"))
    }

    @Test(
        "Display value rounding with .plain (half away from zero)",
        arguments: [
            ("19.2", "1", DisplayUnit.grams, "19"),
            ("19.2", "1", DisplayUnit.germanStandardDrinks, "1.9"),
            ("25.6", "2", DisplayUnit.grams, "26"),
            ("12.5", "0.5", DisplayUnit.grams, "13"),
            ("12.5", "0.5", DisplayUnit.germanStandardDrinks, "1.3"),
            ("12.5", "0.5", DisplayUnit.ukUnits, "1.6"),
            ("19.2", "1.5", DisplayUnit.hu, "1.5"),
        ]
    )
    func displayValueRounding(grams: String, hu: String, unit: DisplayUnit, expected: String) {
        let actual = Units.displayValue(
            grams: Self.dec(grams),
            hu: Self.dec(hu),
            in: unit
        )
        #expect(actual == Self.dec(expected))
    }
}
