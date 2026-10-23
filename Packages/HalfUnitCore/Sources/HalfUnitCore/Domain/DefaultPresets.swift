import Foundation

public struct PresetDefinition: Hashable, Codable, Sendable {
    public let key: String
    public let symbolName: String
    public let hu: Decimal
    public let volumeMl: Int
    public let abvPercent: Decimal

    public var grams: Decimal {
        Units.grams(volumeMl: volumeMl, abvPercent: abvPercent)
    }

    public init(
        key: String,
        symbolName: String,
        hu: Decimal,
        volumeMl: Int,
        abvPercent: Decimal
    ) {
        self.key = key
        self.symbolName = symbolName
        self.hu = hu
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
    }
}

public enum DefaultPresets {
    public static let all: [PresetDefinition] = [
        PresetDefinition(
            key: "smallBeer",
            symbolName: "halfunit.beer.bottle",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            volumeMl: 330,
            abvPercent: Decimal(5)
        ),
        PresetDefinition(
            key: "smallWine",
            symbolName: "halfunit.wine.small",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            volumeMl: 125,
            abvPercent: Decimal(12)
        ),
        PresetDefinition(
            key: "beer",
            symbolName: "halfunit.beer.mug",
            hu: Decimal(1),
            volumeMl: 500,
            abvPercent: Decimal(5)
        ),
        PresetDefinition(
            key: "wineGlass",
            symbolName: "halfunit.wine.glass",
            hu: Decimal(1),
            volumeMl: 200,
            abvPercent: Decimal(12)
        ),
        PresetDefinition(
            key: "shot",
            symbolName: "halfunit.shot",
            hu: Decimal(1),
            volumeMl: 40,
            abvPercent: Decimal(40)
        ),
        PresetDefinition(
            key: "longDrink",
            symbolName: "halfunit.longdrink",
            hu: Decimal(2),
            volumeMl: 80,
            abvPercent: Decimal(40)
        ),
    ]
}
