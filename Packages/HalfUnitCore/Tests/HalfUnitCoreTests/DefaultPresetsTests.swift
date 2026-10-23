import Foundation
import Testing

@testable import HalfUnitCore

@Suite("DefaultPresets Tests")
struct DefaultPresetsTests {
    @Test("DefaultPresets contains the 6 required presets in exact order with valid HU and expected values")
    func defaultPresetsOrderAndValues() {
        let presets = DefaultPresets.all
        #expect(presets.count == 6)

        let expected: [(key: String, volumeMl: Int, abv: Decimal, hu: Decimal, grams: Decimal, symbol: String)] = [
            (
                "smallBeer",
                330,
                Decimal(5),
                Decimal(string: "0.5")!,
                Decimal(string: "13.2")!,
                "halfunit.beer.bottle"
            ),
            (
                "smallWine",
                125,
                Decimal(12),
                Decimal(string: "0.5")!,
                Decimal(12),
                "halfunit.wine.small"
            ),
            (
                "beer",
                500,
                Decimal(5),
                Decimal(1),
                Decimal(20),
                "halfunit.beer.mug"
            ),
            (
                "wineGlass",
                200,
                Decimal(12),
                Decimal(1),
                Decimal(string: "19.2")!,
                "halfunit.wine.glass"
            ),
            (
                "shot",
                40,
                Decimal(40),
                Decimal(1),
                Decimal(string: "12.8")!,
                "halfunit.shot"
            ),
            (
                "longDrink",
                80,
                Decimal(40),
                Decimal(2),
                Decimal(string: "25.6")!,
                "halfunit.longdrink"
            ),
        ]

        for (preset, spec) in zip(presets, expected) {
            #expect(preset.key == spec.key)
            #expect(preset.volumeMl == spec.volumeMl)
            #expect(preset.abvPercent == spec.abv)
            #expect(preset.hu == spec.hu)
            #expect(preset.grams == spec.grams)
            #expect(Units.isValidHU(preset.hu))
            #expect(preset.symbolName == spec.symbol)
        }
    }
}
