import Foundation

public struct WatchStateContext: Codable, Sendable, Equatable {
    public static let currentSchema = 1
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    private enum Keys {
        static let schema = "schema"
        static let currentStreakDays = "currentStreakDays"
        static let isDrinkingToday = "isDrinkingToday"
        static let todayHU = "todayHU"
        static let todayLogicalDayKey = "todayLogicalDayKey"
        static let generatedAt = "generatedAt"
    }

    public var schema: Int = WatchStateContext.currentSchema
    public var currentStreakDays: Int
    public var isDrinkingToday: Bool
    public var todayHU: String
    public var todayLogicalDayKey: Int
    public var generatedAt: Date

    public var todayHUDecimal: Decimal {
        Decimal(string: todayHU, locale: Self.posixLocale) ?? Decimal(0)
    }

    public var todayLogicalDay: LogicalDay? {
        LogicalDay(key: todayLogicalDayKey)
    }

    public init(
        schema: Int = WatchStateContext.currentSchema,
        currentStreakDays: Int,
        isDrinkingToday: Bool,
        todayHU: String,
        todayLogicalDayKey: Int,
        generatedAt: Date
    ) {
        self.schema = schema
        self.currentStreakDays = currentStreakDays
        self.isDrinkingToday = isDrinkingToday
        self.todayHU = todayHU
        self.todayLogicalDayKey = todayLogicalDayKey
        self.generatedAt = generatedAt
    }

    public init(
        schema: Int = WatchStateContext.currentSchema,
        currentStreakDays: Int,
        isDrinkingToday: Bool,
        todayHUDecimal: Decimal,
        todayLogicalDayKey: Int,
        generatedAt: Date
    ) {
        self.init(
            schema: schema,
            currentStreakDays: currentStreakDays,
            isDrinkingToday: isDrinkingToday,
            todayHU: Self.formatDecimal(todayHUDecimal),
            todayLogicalDayKey: todayLogicalDayKey,
            generatedAt: generatedAt
        )
    }

    public init?(dictionary: [String: Any]) {
        guard
            let schema = Self.extractInt(from: dictionary[Keys.schema]),
            schema == Self.currentSchema,
            let currentStreakDays = Self.extractInt(from: dictionary[Keys.currentStreakDays]),
            let isDrinkingToday = dictionary[Keys.isDrinkingToday] as? Bool,
            let todayHU = Self.extractDecimalString(from: dictionary[Keys.todayHU]),
            let todayLogicalDayKey = Self.extractInt(from: dictionary[Keys.todayLogicalDayKey]),
            let generatedAt = Self.extractDate(from: dictionary[Keys.generatedAt])
        else {
            return nil
        }

        self.init(
            schema: schema,
            currentStreakDays: currentStreakDays,
            isDrinkingToday: isDrinkingToday,
            todayHU: todayHU,
            todayLogicalDayKey: todayLogicalDayKey,
            generatedAt: generatedAt
        )
    }

    public func toDictionary() -> [String: Any] {
        [
            Keys.schema: schema,
            Keys.currentStreakDays: currentStreakDays,
            Keys.isDrinkingToday: isDrinkingToday,
            Keys.todayHU: todayHU,
            Keys.todayLogicalDayKey: todayLogicalDayKey,
            Keys.generatedAt: generatedAt,
        ]
    }

    @MainActor
    public static func make(from logService: LogService, generatedAt: Date) throws -> WatchStateContext {
        let currentSettings = try logService.settings()
        let currentToday = try logService.today()
        let snapshots = try logService.snapshots()
        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: currentSettings.firstUseDay,
            today: currentToday
        )
        let streaks = engine.streaks()
        let todaysDrinks = snapshots.filter { $0.logicalDay == currentToday }
        let todayTotalHU = todaysDrinks.reduce(Decimal(0)) { $0 + $1.hu }
        let isDrinkingToday = streaks.isDrinkingToday || !todaysDrinks.isEmpty

        return WatchStateContext(
            currentStreakDays: streaks.currentStreakDays,
            isDrinkingToday: isDrinkingToday,
            todayHUDecimal: todayTotalHU,
            todayLogicalDayKey: currentToday.key,
            generatedAt: generatedAt
        )
    }

    public static func formatDecimal(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: posixLocale)
    }

    private static func extractInt(from raw: Any?) -> Int? {
        if let intValue = raw as? Int {
            return intValue
        }
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            if Double(intValue) == doubleValue {
                return intValue
            }
        }
        return nil
    }

    private static func extractDecimalString(from raw: Any?) -> String? {
        if let stringValue = raw as? String {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let decimal = Decimal(string: trimmed, locale: posixLocale) else {
                return nil
            }
            return formatDecimal(decimal)
        }
        if let intValue = extractInt(from: raw) {
            return String(intValue)
        }
        return nil
    }

    private static func extractDate(from raw: Any?) -> Date? {
        if let date = raw as? Date {
            return date
        }
        if let timeInterval = raw as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return nil
    }
}
