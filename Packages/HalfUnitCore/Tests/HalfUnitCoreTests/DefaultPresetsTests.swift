import Foundation
import Testing

@testable import HalfUnitCore

@Suite("DefaultPresets Tests")
struct DefaultPresetsTests {
    @Test("DefaultPresets contains the 6 required presets in exact order with valid HU and expected values")
    func defaultPresetsOrderAndValues() {
        let presets = DefaultPresets.all
        #expect(presets.count == 6)

        let expected: [(key: String, volumeMl: Int, abv: Decimal, hu: Decimal, grams: Decimal)] = [
            (
                "smallBeer",
                330,
                Decimal(5),
                Decimal(string: "0.5")!,
                Decimal(string: "13.2")!
            ),
            (
                "smallWine",
                125,
                Decimal(12),
                Decimal(string: "0.5")!,
                Decimal(12)
            ),
            (
                "beer",
                500,
                Decimal(5),
                Decimal(1),
                Decimal(20)
            ),
            (
                "wineGlass",
                200,
                Decimal(12),
                Decimal(1),
                Decimal(string: "19.2")!
            ),
            (
                "shot",
                40,
                Decimal(40),
                Decimal(1),
                Decimal(string: "12.8")!
            ),
            (
                "longDrink",
                80,
                Decimal(40),
                Decimal(2),
                Decimal(string: "25.6")!
            ),
        ]

        for (preset, spec) in zip(presets, expected) {
            #expect(preset.key == spec.key)
            #expect(preset.volumeMl == spec.volumeMl)
            #expect(preset.abvPercent == spec.abv)
            #expect(preset.hu == spec.hu)
            #expect(preset.grams == spec.grams)
            #expect(Units.isValidHU(preset.hu))
            #expect(!preset.symbolName.isEmpty)
        }
    }
}
