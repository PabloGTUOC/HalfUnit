import Foundation

public struct DrinkSnapshot: Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let logicalDay: LogicalDay
    public let presetKey: String?
    public let name: String
    public let hu: Decimal
    public let grams: Decimal
    public let deletedAt: Date?

    public init(
        id: UUID,
        timestamp: Date,
        logicalDay: LogicalDay,
        presetKey: String?,
        name: String,
        hu: Decimal,
        grams: Decimal,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.logicalDay = logicalDay
        self.presetKey = presetKey
        self.name = name
        self.hu = hu
        self.grams = grams
        self.deletedAt = deletedAt
    }

    public init(
        id: UUID,
        timestamp: Date,
        timeZone: TimeZone,
        boundaryHour: Int = LogicalDay.defaultBoundaryHour,
        presetKey: String?,
        name: String,
        hu: Decimal,
        grams: Decimal,
        deletedAt: Date? = nil
    ) {
        self.init(
            id: id,
            timestamp: timestamp,
            logicalDay: LogicalDay.of(timestamp, boundaryHour: boundaryHour, timeZone: timeZone),
            presetKey: presetKey,
            name: name,
            hu: hu,
            grams: grams,
            deletedAt: deletedAt
        )
    }
}

public enum Period: Hashable, Sendable {
    case last7Days
    case last30Days
    case last3Months
    case last12Months
    case last2Years
    case custom(from: LogicalDay, through: LogicalDay)

    public func range(endingOn today: LogicalDay) -> ClosedRange<LogicalDay> {
        switch self {
        case .last7Days:
            return today.adding(days: -6)...today
        case .last30Days:
            return today.adding(days: -29)...today
        case .last3Months:
            return today.adding(days: -90)...today
        case .last12Months:
            return today.adding(days: -364)...today
        case .last2Years:
            return today.adding(days: -729)...today
        case .custom(let from, let through):
            return from...through
        }
    }
}

public struct StreakSummary: Hashable, Sendable {
    public let lastDrinkingDay: LogicalDay?
    public let lastDrink: DrinkSnapshot?
    public let isDrinkingToday: Bool
    public let currentStreakDays: Int
    public let previousStreakDays: Int?
    public let longestStreakEver: Int
    public let longestStreakThisYear: Int

    public init(
        lastDrinkingDay: LogicalDay?,
        lastDrink: DrinkSnapshot?,
        isDrinkingToday: Bool,
        currentStreakDays: Int,
        previousStreakDays: Int?,
        longestStreakEver: Int,
        longestStreakThisYear: Int
    ) {
        self.lastDrinkingDay = lastDrinkingDay
        self.lastDrink = lastDrink
        self.isDrinkingToday = isDrinkingToday
        self.currentStreakDays = currentStreakDays
        self.previousStreakDays = previousStreakDays
        self.longestStreakEver = longestStreakEver
        self.longestStreakThisYear = longestStreakThisYear
    }
}

public struct DayTotal: Hashable, Sendable {
    public let day: LogicalDay
    public let drinkCount: Int
    public let hu: Decimal
    public let grams: Decimal

    public init(day: LogicalDay, drinkCount: Int, hu: Decimal, grams: Decimal) {
        self.day = day
        self.drinkCount = drinkCount
        self.hu = hu
        self.grams = grams
    }
}

public struct PeriodStats: Hashable, Sendable {
    public let range: ClosedRange<LogicalDay>
    public let lengthDays: Int
    public let trackedDays: Int
    public let drinkingDays: Int
    public let alcoholFreeDays: Int
    public let drinkingDayShare: Decimal?
    public let totalHU: Decimal
    public let totalGrams: Decimal
    public let averageHUPerDrinkingDay: Decimal?
    public let heaviestDay: DayTotal?

    public init(
        range: ClosedRange<LogicalDay>,
        lengthDays: Int,
        trackedDays: Int,
        drinkingDays: Int,
        alcoholFreeDays: Int,
        drinkingDayShare: Decimal?,
        totalHU: Decimal,
        totalGrams: Decimal,
        averageHUPerDrinkingDay: Decimal?,
        heaviestDay: DayTotal?
    ) {
        self.range = range
        self.lengthDays = lengthDays
        self.trackedDays = trackedDays
        self.drinkingDays = drinkingDays
        self.alcoholFreeDays = alcoholFreeDays
        self.drinkingDayShare = drinkingDayShare
        self.totalHU = totalHU
        self.totalGrams = totalGrams
        self.averageHUPerDrinkingDay = averageHUPerDrinkingDay
        self.heaviestDay = heaviestDay
    }
}

public struct PeriodComparison: Hashable, Sendable {
    public let current: PeriodStats
    public let previous: PeriodStats
    public let drinkingDaysDelta: Int?

    public init(current: PeriodStats, previous: PeriodStats, drinkingDaysDelta: Int?) {
        self.current = current
        self.previous = previous
        self.drinkingDaysDelta = drinkingDaysDelta
    }
}

public struct WeekTotal: Hashable, Sendable {
    public let weekStart: LogicalDay
    public let hu: Decimal
    public let grams: Decimal
    public let drinkingDays: Int

    public init(weekStart: LogicalDay, hu: Decimal, grams: Decimal, drinkingDays: Int) {
        self.weekStart = weekStart
        self.hu = hu
        self.grams = grams
        self.drinkingDays = drinkingDays
    }
}

public struct DrinkTypeTotal: Hashable, Sendable {
    public let presetKey: String?
    public let name: String
    public let drinkCount: Int
    public let hu: Decimal
    public let grams: Decimal

    public init(
        presetKey: String?,
        name: String,
        drinkCount: Int,
        hu: Decimal,
        grams: Decimal
    ) {
        self.presetKey = presetKey
        self.name = name
        self.drinkCount = drinkCount
        self.hu = hu
        self.grams = grams
    }
}

public struct WeekdayTotal: Hashable, Sendable {
    public let weekday: Weekday
    public let drinkingDays: Int
    public let shareOfDrinkingDays: Decimal?

    public init(weekday: Weekday, drinkingDays: Int, shareOfDrinkingDays: Decimal?) {
        self.weekday = weekday
        self.drinkingDays = drinkingDays
        self.shareOfDrinkingDays = shareOfDrinkingDays
    }
}
