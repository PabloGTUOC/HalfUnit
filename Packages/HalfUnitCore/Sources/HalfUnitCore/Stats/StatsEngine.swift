import Foundation

public struct StatsEngine: Sendable {
    private struct DayBucket: Sendable {
        var total: DayTotal
        var drinks: [DrinkSnapshot]
    }

    private enum GroupKey: Hashable, Sendable {
        case preset(String)
        case custom(String)
    }

    private let today: LogicalDay
    private let effectiveFirstUseDay: LogicalDay
    private let sortedDrinkingDays: [LogicalDay]
    private let dayBuckets: [LogicalDay: DayBucket]
    private let lastDrinkSnapshot: DrinkSnapshot?

    public init(drinks: [DrinkSnapshot], firstUseDay: LogicalDay, today: LogicalDay) {
        self.today = today

        let validDrinks = drinks.filter { $0.deletedAt == nil && $0.logicalDay <= today }

        var buckets: [LogicalDay: DayBucket] = [:]
        var latestDrink: DrinkSnapshot?

        for drink in validDrinks {
            if let currentLatest = latestDrink {
                if drink.timestamp > currentLatest.timestamp {
                    latestDrink = drink
                } else if drink.timestamp == currentLatest.timestamp
                    && drink.id.uuidString > currentLatest.id.uuidString
                {
                    latestDrink = drink
                }
            } else {
                latestDrink = drink
            }

            if var bucket = buckets[drink.logicalDay] {
                bucket.total = DayTotal(
                    day: drink.logicalDay,
                    drinkCount: bucket.total.drinkCount + 1,
                    hu: bucket.total.hu + drink.hu,
                    grams: bucket.total.grams + drink.grams
                )
                bucket.drinks.append(drink)
                buckets[drink.logicalDay] = bucket
            } else {
                let total = DayTotal(
                    day: drink.logicalDay,
                    drinkCount: 1,
                    hu: drink.hu,
                    grams: drink.grams
                )
                buckets[drink.logicalDay] = DayBucket(total: total, drinks: [drink])
            }
        }

        let sortedDays = buckets.keys.sorted()
        self.sortedDrinkingDays = sortedDays
        self.dayBuckets = buckets
        self.lastDrinkSnapshot = latestDrink

        if let earliestDrinkingDay = sortedDays.first {
            self.effectiveFirstUseDay = min(firstUseDay, earliestDrinkingDay)
        } else {
            self.effectiveFirstUseDay = firstUseDay
        }
    }

    public func streaks() -> StreakSummary {
        let virtualDrinkingDay = effectiveFirstUseDay.adding(days: -1)
        let lastDrinkingDay = sortedDrinkingDays.last
        let isDrinkingToday = (lastDrinkingDay == today)

        let currentStreakDays: Int
        let previousStreakDays: Int?

        if let lastDay = lastDrinkingDay {
            if isDrinkingToday {
                currentStreakDays = 0
                let previousDay =
                    sortedDrinkingDays.count >= 2
                    ? sortedDrinkingDays[sortedDrinkingDays.count - 2]
                    : virtualDrinkingDay
                previousStreakDays = previousDay.days(to: today) - 1
            } else {
                currentStreakDays = lastDay.days(to: today)
                previousStreakDays = nil
            }
        } else {
            currentStreakDays = virtualDrinkingDay.days(to: today)
            previousStreakDays = nil
        }

        let yearStart = LogicalDay(year: today.year, month: 1, day: 1)
        var longestEver = 0
        var longestThisYear = 0

        func recordRun(after startBoundary: LogicalDay, before endBoundary: LogicalDay) {
            let runDays = startBoundary.days(to: endBoundary) - 1
            if runDays > longestEver {
                longestEver = runDays
            }
            if runDays > 0 {
                let runStart = startBoundary.adding(days: 1)
                let runEnd = endBoundary.adding(days: -1)
                let clippedStart = max(runStart, yearStart)
                let clippedEnd = min(runEnd, today)
                if clippedStart <= clippedEnd {
                    let yearDays = clippedStart.days(to: clippedEnd) + 1
                    if yearDays > longestThisYear {
                        longestThisYear = yearDays
                    }
                }
            }
        }

        var previousBoundary = virtualDrinkingDay
        for drinkingDay in sortedDrinkingDays {
            recordRun(after: previousBoundary, before: drinkingDay)
            previousBoundary = drinkingDay
        }
        // Current run after the last drinking day (or virtual drinking day) through today inclusive
        recordRun(after: previousBoundary, before: today.adding(days: 1))

        return StreakSummary(
            lastDrinkingDay: lastDrinkingDay,
            lastDrink: lastDrinkSnapshot,
            isDrinkingToday: isDrinkingToday,
            currentStreakDays: currentStreakDays,
            previousStreakDays: previousStreakDays,
            longestStreakEver: longestEver,
            longestStreakThisYear: longestThisYear
        )
    }

    public func stats(for period: Period) -> PeriodStats {
        let range = period.range(endingOn: today)
        let lengthDays = range.lowerBound.days(to: range.upperBound) + 1

        guard let trackedRange = trackedSubrange(of: range) else {
            return PeriodStats(
                range: range,
                lengthDays: lengthDays,
                trackedDays: 0,
                drinkingDays: 0,
                alcoholFreeDays: 0,
                drinkingDayShare: nil,
                totalHU: Decimal(0),
                totalGrams: Decimal(0),
                averageHUPerDrinkingDay: nil,
                heaviestDay: nil
            )
        }

        let trackedDays = trackedRange.lowerBound.days(to: trackedRange.upperBound) + 1
        var drinkingDays = 0
        var totalHU = Decimal(0)
        var totalGrams = Decimal(0)
        var heaviestDay: DayTotal?

        var day = trackedRange.lowerBound
        while day <= trackedRange.upperBound {
            if let bucket = dayBuckets[day] {
                let dayTotal = bucket.total
                drinkingDays += 1
                totalHU += dayTotal.hu
                totalGrams += dayTotal.grams

                if let currentHeaviest = heaviestDay {
                    if dayTotal.hu > currentHeaviest.hu
                        || (dayTotal.hu == currentHeaviest.hu && dayTotal.grams > currentHeaviest.grams)
                        || (dayTotal.hu == currentHeaviest.hu
                            && dayTotal.grams == currentHeaviest.grams
                            && dayTotal.day > currentHeaviest.day)
                    {
                        heaviestDay = dayTotal
                    }
                } else {
                    heaviestDay = dayTotal
                }
            }
            day = day.adding(days: 1)
        }

        let alcoholFreeDays = trackedDays - drinkingDays
        let drinkingDayShare = Decimal(drinkingDays) / Decimal(trackedDays)
        let averageHUPerDrinkingDay =
            drinkingDays > 0 ? (totalHU / Decimal(drinkingDays)) : nil

        return PeriodStats(
            range: range,
            lengthDays: lengthDays,
            trackedDays: trackedDays,
            drinkingDays: drinkingDays,
            alcoholFreeDays: alcoholFreeDays,
            drinkingDayShare: drinkingDayShare,
            totalHU: totalHU,
            totalGrams: totalGrams,
            averageHUPerDrinkingDay: averageHUPerDrinkingDay,
            heaviestDay: heaviestDay
        )
    }

    public func comparison(for period: Period) -> PeriodComparison {
        let currentStats = stats(for: period)
        let length = currentStats.lengthDays
        let previousEnd = currentStats.range.lowerBound.adding(days: -1)
        let previousStart = previousEnd.adding(days: -(length - 1))
        let previousStats = stats(for: .custom(from: previousStart, through: previousEnd))

        let delta: Int? =
            previousStats.trackedDays > 0
            ? (currentStats.drinkingDays - previousStats.drinkingDays)
            : nil

        return PeriodComparison(
            current: currentStats,
            previous: previousStats,
            drinkingDaysDelta: delta
        )
    }

    public func dailyTotals(for period: Period) -> [DayTotal] {
        let range = period.range(endingOn: today)
        guard let trackedRange = trackedSubrange(of: range) else {
            return []
        }

        var totals: [DayTotal] = []
        totals.reserveCapacity(trackedRange.lowerBound.days(to: trackedRange.upperBound) + 1)

        var day = trackedRange.lowerBound
        while day <= trackedRange.upperBound {
            if let bucket = dayBuckets[day] {
                totals.append(bucket.total)
            } else {
                totals.append(DayTotal(day: day, drinkCount: 0, hu: Decimal(0), grams: Decimal(0)))
            }
            day = day.adding(days: 1)
        }
        return totals
    }

    public func weeklyTotals(for period: Period, weekStartsOn: Weekday = .monday) -> [WeekTotal] {
        let range = period.range(endingOn: today)
        let firstWeekStart = startOfWeek(for: range.lowerBound, weekStartsOn: weekStartsOn)
        let lastWeekStart = startOfWeek(for: range.upperBound, weekStartsOn: weekStartsOn)

        let trackedRange = trackedSubrange(of: range)

        var results: [WeekTotal] = []
        var currentWeekStart = firstWeekStart

        while currentWeekStart <= lastWeekStart {
            let currentWeekEnd = currentWeekStart.adding(days: 6)
            var weekHU = Decimal(0)
            var weekGrams = Decimal(0)
            var weekDrinkingDays = 0

            if let trackedRange {
                let effectiveStart = max(currentWeekStart, trackedRange.lowerBound)
                let effectiveEnd = min(currentWeekEnd, trackedRange.upperBound)
                if effectiveStart <= effectiveEnd {
                    var day = effectiveStart
                    while day <= effectiveEnd {
                        if let bucket = dayBuckets[day] {
                            weekHU += bucket.total.hu
                            weekGrams += bucket.total.grams
                            weekDrinkingDays += 1
                        }
                        day = day.adding(days: 1)
                    }
                }
            }

            results.append(
                WeekTotal(
                    weekStart: currentWeekStart,
                    hu: weekHU,
                    grams: weekGrams,
                    drinkingDays: weekDrinkingDays
                )
            )
            currentWeekStart = currentWeekStart.adding(days: 7)
        }

        return results
    }

    public func drinkTypeBreakdown(for period: Period) -> [DrinkTypeTotal] {
        let range = period.range(endingOn: today)
        guard let trackedRange = trackedSubrange(of: range) else {
            return []
        }

        struct Accumulator {
            let presetKey: String?
            var latestDrink: DrinkSnapshot
            var count: Int
            var hu: Decimal
            var grams: Decimal
        }

        var groups: [GroupKey: Accumulator] = [:]

        var day = trackedRange.lowerBound
        while day <= trackedRange.upperBound {
            if let bucket = dayBuckets[day] {
                for drink in bucket.drinks {
                    let key: GroupKey =
                        if let presetKey = drink.presetKey {
                            .preset(presetKey)
                        } else {
                            .custom(drink.name)
                        }

                    if var acc = groups[key] {
                        acc.count += 1
                        acc.hu += drink.hu
                        acc.grams += drink.grams
                        if drink.timestamp > acc.latestDrink.timestamp
                            || (drink.timestamp == acc.latestDrink.timestamp
                                && drink.id.uuidString > acc.latestDrink.id.uuidString)
                        {
                            acc.latestDrink = drink
                        }
                        groups[key] = acc
                    } else {
                        groups[key] = Accumulator(
                            presetKey: drink.presetKey,
                            latestDrink: drink,
                            count: 1,
                            hu: drink.hu,
                            grams: drink.grams
                        )
                    }
                }
            }
            day = day.adding(days: 1)
        }

        return groups.values
            .map { acc in
                DrinkTypeTotal(
                    presetKey: acc.presetKey,
                    name: acc.latestDrink.name,
                    drinkCount: acc.count,
                    hu: acc.hu,
                    grams: acc.grams
                )
            }
            .sorted { lhs, rhs in
                if lhs.hu != rhs.hu {
                    return lhs.hu > rhs.hu
                }
                if lhs.name != rhs.name {
                    return lhs.name < rhs.name
                }
                return (lhs.presetKey ?? "") < (rhs.presetKey ?? "")
            }
    }

    public func weekdayBreakdown(for period: Period) -> [WeekdayTotal] {
        let range = period.range(endingOn: today)
        var countsByWeekday: [Weekday: Int] = [:]
        var totalDrinkingDays = 0

        if let trackedRange = trackedSubrange(of: range) {
            var day = trackedRange.lowerBound
            while day <= trackedRange.upperBound {
                if dayBuckets[day] != nil {
                    countsByWeekday[day.weekday, default: 0] += 1
                    totalDrinkingDays += 1
                }
                day = day.adding(days: 1)
            }
        }

        return Weekday.allCases.map { weekday in
            let count = countsByWeekday[weekday, default: 0]
            let share: Decimal? =
                totalDrinkingDays > 0
                ? (Decimal(count) / Decimal(totalDrinkingDays))
                : nil
            return WeekdayTotal(
                weekday: weekday,
                drinkingDays: count,
                shareOfDrinkingDays: share
            )
        }
    }

    private func trackedSubrange(of range: ClosedRange<LogicalDay>) -> ClosedRange<LogicalDay>? {
        let start = max(range.lowerBound, effectiveFirstUseDay)
        let end = min(range.upperBound, today)
        guard start <= end else {
            return nil
        }
        return start...end
    }

    private func startOfWeek(for day: LogicalDay, weekStartsOn: Weekday) -> LogicalDay {
        let offset = (day.weekday.rawValue - weekStartsOn.rawValue + 7) % 7
        return day.adding(days: -offset)
    }
}
