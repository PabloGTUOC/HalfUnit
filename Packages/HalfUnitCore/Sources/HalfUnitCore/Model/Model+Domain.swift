import Foundation

public enum DrinkSource: String, Codable, Sendable, CaseIterable {
    case watch
    case phone
    case widget
    case siri
    case healthImport
}

enum IntegerStorageConversion {
    private static let fallbackUTC = TimeZone(identifier: "UTC")!

    static func huToHalfSteps(_ hu: Decimal) -> Int {
        scaledInt(hu, multiplier: 2)
    }

    static func halfStepsToHU(_ halfSteps: Int) -> Decimal {
        let sign: FloatingPointSign = halfSteps < 0 ? .minus : .plus
        return Decimal(
            sign: sign,
            exponent: -1,
            significand: Decimal(halfSteps.magnitude) * Decimal(5)
        )
    }

    static func gramsToCentigrams(_ grams: Decimal) -> Int {
        scaledInt(grams, multiplier: 100)
    }

    static func centigramsToGrams(_ centigrams: Int) -> Decimal {
        let sign: FloatingPointSign = centigrams < 0 ? .minus : .plus
        return Decimal(
            sign: sign,
            exponent: -2,
            significand: Decimal(centigrams.magnitude)
        )
    }

    static func abvToTenths(_ abvPercent: Decimal) -> Int {
        scaledInt(abvPercent, multiplier: 10)
    }

    static func tenthsToABV(_ tenths: Int) -> Decimal {
        let sign: FloatingPointSign = tenths < 0 ? .minus : .plus
        return Decimal(
            sign: sign,
            exponent: -1,
            significand: Decimal(tenths.magnitude)
        )
    }

    static func resolveTimeZone(_ identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? fallbackUTC
    }

    private static func scaledInt(_ value: Decimal, multiplier: Int) -> Int {
        var scaled = value * Decimal(multiplier)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

extension Drink {
    public var hu: Decimal {
        get { IntegerStorageConversion.halfStepsToHU(huHalfSteps) }
        set { huHalfSteps = IntegerStorageConversion.huToHalfSteps(newValue) }
    }

    public var grams: Decimal {
        get { IntegerStorageConversion.centigramsToGrams(centigrams) }
        set { centigrams = IntegerStorageConversion.gramsToCentigrams(newValue) }
    }

    public var abvPercent: Decimal? {
        get { abvTenths.map(IntegerStorageConversion.tenthsToABV) }
        set { abvTenths = newValue.map(IntegerStorageConversion.abvToTenths) }
    }

    public var source: DrinkSource {
        get { DrinkSource(rawValue: sourceRaw) ?? .phone }
        set { sourceRaw = newValue.rawValue }
    }

    public var timeZone: TimeZone {
        get { IntegerStorageConversion.resolveTimeZone(timeZoneIdentifier) }
        set { timeZoneIdentifier = newValue.identifier }
    }

    public var logicalDay: LogicalDay {
        get {
            LogicalDay(key: logicalDayKey)
                ?? LogicalDay.of(
                    timestamp,
                    boundaryHour: LogicalDay.defaultBoundaryHour,
                    timeZone: timeZone
                )
        }
        set { logicalDayKey = newValue.key }
    }

    public func snapshot() -> DrinkSnapshot {
        snapshot(presetKey: nil)
    }

    public func snapshot(presetKey: String?) -> DrinkSnapshot {
        DrinkSnapshot(
            id: id,
            timestamp: timestamp,
            logicalDay: logicalDay,
            presetKey: presetKey,
            name: name,
            hu: hu,
            grams: grams,
            deletedAt: deletedAt
        )
    }
}

extension Preset {
    public var hu: Decimal {
        get { IntegerStorageConversion.halfStepsToHU(huHalfSteps) }
        set { huHalfSteps = IntegerStorageConversion.huToHalfSteps(newValue) }
    }

    public var abvPercent: Decimal {
        get { IntegerStorageConversion.tenthsToABV(abvTenths) }
        set { abvTenths = IntegerStorageConversion.abvToTenths(newValue) }
    }

    public var grams: Decimal {
        Units.grams(volumeMl: volumeMl, abvPercent: abvPercent)
    }
}

extension AppSettings {
    public var displayUnit: DisplayUnit {
        get { DisplayUnit(rawValue: displayUnitRaw) ?? .hu }
        set { displayUnitRaw = newValue.rawValue }
    }

    public var firstUseDay: LogicalDay {
        get { LogicalDay(key: firstUseDayKey) ?? LogicalDay(year: 1970, month: 1, day: 1) }
        set { firstUseDayKey = newValue.key }
    }
}
