import Foundation
import HalfUnitCore

enum InsightsPeriodOption: String, CaseIterable, Identifiable, Sendable {
    case last7Days = "7d"
    case last30Days = "30d"
    case last3Months = "3m"
    case last12Months = "12m"
    case last2Years = "2y"
    case custom = "custom"

    var id: String { rawValue }

    var pickerLabelKey: String {
        switch self {
        case .last7Days:
            return "insights.period.7d"
        case .last30Days:
            return "insights.period.30d"
        case .last3Months:
            return "insights.period.3m"
        case .last12Months:
            return "insights.period.12m"
        case .last2Years:
            return "insights.period.2y"
        case .custom:
            return "insights.period.custom"
        }
    }

    var comparisonPeriodNameKey: String {
        switch self {
        case .last7Days:
            return "insights.period.name.7d"
        case .last30Days:
            return "insights.period.name.30d"
        case .last3Months:
            return "insights.period.name.3m"
        case .last12Months:
            return "insights.period.name.12m"
        case .last2Years:
            return "insights.period.name.2y"
        case .custom:
            return "insights.period.name.custom"
        }
    }

    func toPeriod(customFrom: LogicalDay, customThrough: LogicalDay) -> Period {
        switch self {
        case .last7Days:
            return .last7Days
        case .last30Days:
            return .last30Days
        case .last3Months:
            return .last3Months
        case .last12Months:
            return .last12Months
        case .last2Years:
            return .last2Years
        case .custom:
            let start = min(customFrom, customThrough)
            let end = max(customFrom, customThrough)
            return .custom(from: start, through: end)
        }
    }

    static func customPeriod(
        from startDate: Date,
        through endDate: Date,
        boundaryHour: Int,
        timeZone: TimeZone
    ) -> Period {
        let resolvedBoundary =
            (0...23).contains(boundaryHour) ? boundaryHour : LogicalDay.defaultBoundaryHour
        let startDay = LogicalDay.of(startDate, boundaryHour: resolvedBoundary, timeZone: timeZone)
        let endDay = LogicalDay.of(endDate, boundaryHour: resolvedBoundary, timeZone: timeZone)
        return .custom(from: min(startDay, endDay), through: max(startDay, endDay))
    }
}

enum AmountFormatting {
    static func formattedValue(
        grams: Decimal,
        hu: Decimal,
        in unit: DisplayUnit,
        locale: Locale = .current
    ) -> String {
        let rounded = Units.displayValue(grams: grams, hu: hu, in: unit)
        return formattedDisplayDecimal(rounded, in: unit, locale: locale)
    }

    static func formattedHUOnly(
        _ hu: Decimal,
        in unit: DisplayUnit,
        locale: Locale = .current
    ) -> String {
        let grams = Units.estimatedGrams(hu: hu)
        return formattedValue(grams: grams, hu: hu, in: unit, locale: locale)
    }

    static func formattedGrams(_ grams: Decimal, locale: Locale = .current) -> String {
        formattedValue(grams: grams, hu: Decimal(0), in: .grams, locale: locale)
    }

    static func formattedHU(_ hu: Decimal, locale: Locale = .current) -> String {
        PresetPresentation.formattedHU(hu, locale: locale)
    }

    static func spokenUnits(_ hu: Decimal, locale: Locale = .current) -> String {
        if hu == Decimal(1) {
            return AppLocalization.string("unit.spokenUnits.one", locale: locale)
        }
        let numberText = PresetPresentation.formattedHUNumber(hu, locale: locale)
        let format = AppLocalization.string("unit.spokenUnits.other", locale: locale)
        return String(format: format, locale: locale, numberText)
    }

    private static func formattedDisplayDecimal(
        _ value: Decimal,
        in unit: DisplayUnit,
        locale: Locale
    ) -> String {
        let fractionRange: ClosedRange<Int> =
            switch unit {
            case .grams:
                0...0
            case .hu, .germanStandardDrinks, .ukUnits:
                0...1
            }

        let numberText = value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(fractionRange))
        )

        let formatKey: String =
            switch unit {
            case .hu:
                "unit.huValue"
            case .grams:
                "unit.gramsValue"
            case .germanStandardDrinks:
                "unit.germanStandardDrinksValue"
            case .ukUnits:
                "unit.ukUnitsValue"
            }

        let format = AppLocalization.string(formatKey, locale: locale)
        return String(format: format, locale: locale, numberText)
    }
}

struct InsightsSummaryModel: Equatable, Sendable {
    let drinkingDaysText: String
    let drinkingDayShareText: String
    let alcoholFreeDaysText: String
    let totalPrimaryText: String
    let totalSecondaryText: String
    let totalHUText: String
    let totalGramsText: String
    let averagePerDrinkingDayText: String
    let heaviestDayText: String
    let deltaText: String?

    init(
        comparison: PeriodComparison,
        periodOption: InsightsPeriodOption,
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) {
        let stats = comparison.current

        if stats.trackedDays < stats.lengthDays {
            let format = AppLocalization.string(
                "insights.summary.drinkingDaysOfTrackedDays",
                locale: locale
            )
            self.drinkingDaysText = String(
                format: format,
                locale: locale,
                Int64(stats.drinkingDays),
                Int64(stats.trackedDays)
            )
        } else {
            let format = AppLocalization.string(
                "insights.summary.drinkingDaysOfDays",
                locale: locale
            )
            self.drinkingDaysText = String(
                format: format,
                locale: locale,
                Int64(stats.drinkingDays),
                Int64(stats.lengthDays)
            )
        }

        if let share = stats.drinkingDayShare {
            let percentText = Self.formatPercentage(share, locale: locale)
            let format = AppLocalization.string("insights.summary.shareOfDays", locale: locale)
            self.drinkingDayShareText = String(format: format, locale: locale, percentText)
        } else {
            self.drinkingDayShareText = AppLocalization.string(
                "insights.summary.none",
                locale: locale
            )
        }

        self.alcoholFreeDaysText = AppLocalization.plural(
            "insights.summary.alcoholFreeDays.value",
            count: stats.alcoholFreeDays,
            locale: locale
        )

        let totalHUText = AmountFormatting.formattedHU(stats.totalHU, locale: locale)
        let totalGramsText = AmountFormatting.formattedGrams(stats.totalGrams, locale: locale)
        self.totalHUText = totalHUText
        self.totalGramsText = totalGramsText

        let primaryAmount = AmountFormatting.formattedValue(
            grams: stats.totalGrams,
            hu: stats.totalHU,
            in: displayUnit,
            locale: locale
        )
        self.totalPrimaryText = primaryAmount
        switch displayUnit {
        case .hu:
            self.totalSecondaryText = totalGramsText
        case .grams:
            self.totalSecondaryText = totalHUText
        case .germanStandardDrinks, .ukUnits:
            self.totalSecondaryText = "\(totalHUText) · \(totalGramsText)"
        }

        if let avgHU = stats.averageHUPerDrinkingDay {
            let avgGrams =
                stats.drinkingDays > 0
                ? (stats.totalGrams / Decimal(stats.drinkingDays))
                : Units.estimatedGrams(hu: avgHU)
            self.averagePerDrinkingDayText = AmountFormatting.formattedValue(
                grams: avgGrams,
                hu: avgHU,
                in: displayUnit,
                locale: locale
            )
        } else {
            self.averagePerDrinkingDayText = AppLocalization.string(
                "insights.summary.none",
                locale: locale
            )
        }

        if let heaviest = stats.heaviestDay {
            let dateText = StreakCardModel.formatLogicalDay(heaviest.day, locale: locale)
            let amountText = AmountFormatting.formattedValue(
                grams: heaviest.grams,
                hu: heaviest.hu,
                in: displayUnit,
                locale: locale
            )
            let format = AppLocalization.string(
                "insights.summary.heaviestDay.value",
                locale: locale
            )
            self.heaviestDayText = String(format: format, locale: locale, dateText, amountText)
        } else {
            self.heaviestDayText = AppLocalization.string("insights.summary.none", locale: locale)
        }

        self.deltaText = Self.formatDelta(
            comparison.drinkingDaysDelta,
            periodOption: periodOption,
            locale: locale
        )
    }

    static func formatDelta(
        _ delta: Int?,
        periodOption: InsightsPeriodOption,
        locale: Locale = .current
    ) -> String? {
        guard let delta else {
            return nil
        }
        let periodName = AppLocalization.string(periodOption.comparisonPeriodNameKey, locale: locale)
        if delta < 0 {
            let magnitude = abs(delta)
            let format = AppLocalization.string("insights.delta.fewer", locale: locale)
            return String(format: format, locale: locale, Int64(magnitude), periodName)
        } else if delta > 0 {
            let format = AppLocalization.string("insights.delta.more", locale: locale)
            return String(format: format, locale: locale, Int64(delta), periodName)
        } else {
            let format = AppLocalization.string("insights.delta.same", locale: locale)
            return String(format: format, locale: locale, periodName)
        }
    }

    static func formatPercentage(_ share: Decimal, locale: Locale = .current) -> String {
        var scaled = share * Decimal(100)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        let wholePercent = NSDecimalNumber(decimal: rounded).intValue
        return "\(wholePercent)%"
    }
}

struct InsightsHeatmapCellModel: Identifiable, Equatable, Sendable {
    let day: LogicalDay
    let weekIndex: Int
    let weekday: Weekday
    let hu: Decimal
    let grams: Decimal
    let drinkCount: Int
    let intensity: Double
    let accessibilityLabel: String

    var id: Int { day.key }
}

struct InsightsWeeklyBarModel: Identifiable, Equatable, Sendable {
    let weekStart: LogicalDay
    let weekStartDate: Date
    let hu: Decimal
    let grams: Decimal
    let drinkingDays: Int
    let displayValue: Double
    let displayText: String
    let accessibilityLabel: String

    var id: Int { weekStart.key }
}

struct InsightsWeekdayRowModel: Identifiable, Equatable, Sendable {
    let weekday: Weekday
    let shortName: String
    let pluralName: String
    let drinkingDays: Int
    let share: Decimal?
    let sharePercentText: String
    let isTop: Bool
    let accessibilityLabel: String

    var id: Int { weekday.rawValue }
}

struct InsightsDrinkTypeRowModel: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let symbolName: String
    let count: Int
    let countText: String
    let hu: Decimal
    let grams: Decimal
    let primaryAmountText: String
    let gramsText: String
}

struct InsightsStreaksModel: Equatable, Sendable {
    let longestEverDays: Int
    let longestEverText: String
    let longestThisYearDays: Int
    let longestThisYearText: String

    init(summary: StreakSummary, locale: Locale = .current) {
        self.longestEverDays = summary.longestStreakEver
        self.longestEverText = AppLocalization.plural(
            "insights.streaks.days",
            count: summary.longestStreakEver,
            locale: locale
        )
        self.longestThisYearDays = summary.longestStreakThisYear
        self.longestThisYearText = AppLocalization.plural(
            "insights.streaks.days",
            count: summary.longestStreakThisYear,
            locale: locale
        )
    }
}

struct InsightsScreenSnapshot: Equatable, Sendable {
    let isEmpty: Bool
    let periodOption: InsightsPeriodOption
    let period: Period
    let displayUnit: DisplayUnit
    let summary: InsightsSummaryModel
    let heatmapCells: [InsightsHeatmapCellModel]
    let heatmapSummaryAccessibilityLabel: String
    let weeklyBars: [InsightsWeeklyBarModel]
    let weeklySummaryAccessibilityLabel: String
    let topWeekdaySentence: String?
    let weekdayRows: [InsightsWeekdayRowModel]
    let drinkTypeRows: [InsightsDrinkTypeRowModel]
    let streaks: InsightsStreaksModel

    init(
        engine: StatsEngine,
        hasAnyTrackedDrinks: Bool,
        periodOption: InsightsPeriodOption,
        period: Period,
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) {
        self.isEmpty = !hasAnyTrackedDrinks
        self.periodOption = periodOption
        self.period = period
        self.displayUnit = displayUnit

        let comparison = engine.comparison(for: period)
        self.summary = InsightsSummaryModel(
            comparison: comparison,
            periodOption: periodOption,
            displayUnit: displayUnit,
            locale: locale
        )

        let daily = engine.dailyTotals(for: period)
        self.heatmapCells = Self.buildHeatmapCells(from: daily, locale: locale)
        self.heatmapSummaryAccessibilityLabel = Self.buildHeatmapSummaryAccessibility(
            stats: comparison.current,
            locale: locale
        )

        let weekly = engine.weeklyTotals(for: period, weekStartsOn: .monday)
        self.weeklyBars = Self.buildWeeklyBars(
            from: weekly,
            displayUnit: displayUnit,
            locale: locale
        )
        self.weeklySummaryAccessibilityLabel = Self.buildWeeklySummaryAccessibility(
            weeksCount: weekly.count,
            stats: comparison.current,
            displayUnit: displayUnit,
            locale: locale
        )

        let weekdayTotals = engine.weekdayBreakdown(for: period)
        let (topSentence, builtWeekdays) = Self.buildWeekdays(from: weekdayTotals, locale: locale)
        self.topWeekdaySentence = topSentence
        self.weekdayRows = builtWeekdays

        let drinkTypes = engine.drinkTypeBreakdown(for: period)
        self.drinkTypeRows = Self.buildDrinkTypes(
            from: drinkTypes,
            displayUnit: displayUnit,
            locale: locale
        )

        self.streaks = InsightsStreaksModel(summary: engine.streaks(), locale: locale)
    }

    @MainActor
    static func load(
        from logService: LogService,
        periodOption: InsightsPeriodOption,
        customFrom: LogicalDay? = nil,
        customThrough: LogicalDay? = nil,
        locale: Locale = .current
    ) throws -> InsightsScreenSnapshot {
        let currentSettings = try logService.settings()
        let currentToday = try logService.today()
        let snapshots = try logService.snapshots()
        let activeSnapshots = snapshots.filter { $0.deletedAt == nil && $0.logicalDay <= currentToday }

        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: currentSettings.firstUseDay,
            today: currentToday
        )

        let defaultFrom = currentToday.adding(days: -29)
        let resolvedPeriod = periodOption.toPeriod(
            customFrom: customFrom ?? defaultFrom,
            customThrough: customThrough ?? currentToday
        )

        return InsightsScreenSnapshot(
            engine: engine,
            hasAnyTrackedDrinks: !activeSnapshots.isEmpty,
            periodOption: periodOption,
            period: resolvedPeriod,
            displayUnit: currentSettings.displayUnit,
            locale: locale
        )
    }

    static func buildHeatmapCells(
        from dailyTotals: [DayTotal],
        locale: Locale = .current
    ) -> [InsightsHeatmapCellModel] {
        guard let firstDay = dailyTotals.first?.day else {
            return []
        }

        let maxHU = dailyTotals.map(\.hu).max() ?? Decimal(0)
        let maxHUDouble = max(NSDecimalNumber(decimal: maxHU).doubleValue, 1.0)
        let firstMonday = startOfMondayWeek(for: firstDay)

        return dailyTotals.map { item in
            let daysFromFirstMonday = firstMonday.days(to: item.day)
            let weekIndex = max(0, daysFromFirstMonday / 7)
            let huDouble = NSDecimalNumber(decimal: item.hu).doubleValue
            let intensity: Double
            if item.hu <= Decimal(0) {
                intensity = 0
            } else {
                let normalized = min(1.0, max(0.0, huDouble / maxHUDouble))
                intensity = 0.25 + (0.75 * normalized)
            }

            let dateString = StreakCardModel.formatLogicalDay(item.day, locale: locale)
            let unitsString = AmountFormatting.spokenUnits(item.hu, locale: locale)
            let labelFormat = AppLocalization.string(
                "insights.heatmap.cell.accessibility",
                locale: locale
            )
            let label = String(format: labelFormat, locale: locale, dateString, unitsString)

            return InsightsHeatmapCellModel(
                day: item.day,
                weekIndex: weekIndex,
                weekday: item.day.weekday,
                hu: item.hu,
                grams: item.grams,
                drinkCount: item.drinkCount,
                intensity: intensity,
                accessibilityLabel: label
            )
        }
    }

    static func buildWeeklyBars(
        from weeklyTotals: [WeekTotal],
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) -> [InsightsWeeklyBarModel] {
        weeklyTotals.map { week in
            let displayDecimal = Units.displayValue(
                grams: week.grams,
                hu: week.hu,
                in: displayUnit
            )
            let displayDouble = NSDecimalNumber(decimal: displayDecimal).doubleValue
            let displayText = AmountFormatting.formattedValue(
                grams: week.grams,
                hu: week.hu,
                in: displayUnit,
                locale: locale
            )
            let dateString = StreakCardModel.formatLogicalDay(week.weekStart, locale: locale)
            let format = AppLocalization.string("insights.weekly.bar.accessibility", locale: locale)
            let accessibilityLabel = String(
                format: format,
                locale: locale,
                dateString,
                displayText
            )

            return InsightsWeeklyBarModel(
                weekStart: week.weekStart,
                weekStartDate: logicalDayToUTCDate(week.weekStart),
                hu: week.hu,
                grams: week.grams,
                drinkingDays: week.drinkingDays,
                displayValue: displayDouble,
                displayText: displayText,
                accessibilityLabel: accessibilityLabel
            )
        }
    }

    static func buildWeekdays(
        from weekdayTotals: [WeekdayTotal],
        locale: Locale = .current
    ) -> (topSentence: String?, rows: [InsightsWeekdayRowModel]) {
        let maxDrinkingDays = weekdayTotals.map(\.drinkingDays).max() ?? 0
        let topWeekday: Weekday? =
            maxDrinkingDays > 0
            ? weekdayTotals.first(where: { $0.drinkingDays == maxDrinkingDays })?.weekday
            : nil

        var topSentence: String?
        let rows: [InsightsWeekdayRowModel] = weekdayTotals.map { entry in
            let isTop = (entry.weekday == topWeekday && entry.drinkingDays > 0)
            let shortName = shortWeekdayName(for: entry.weekday, locale: locale)
            let pluralName = pluralWeekdayName(for: entry.weekday, locale: locale)
            let sharePercentText: String
            if let share = entry.shareOfDrinkingDays {
                sharePercentText = InsightsSummaryModel.formatPercentage(share, locale: locale)
            } else {
                sharePercentText = "0%"
            }

            if isTop, topSentence == nil {
                let format = AppLocalization.string("insights.weekday.topSentence", locale: locale)
                topSentence = String(format: format, locale: locale, pluralName, sharePercentText)
            }

            let daysText = AppLocalization.plural(
                "insights.streaks.days",
                count: entry.drinkingDays,
                locale: locale
            )
            let rowFormat = AppLocalization.string(
                "insights.weekday.row.accessibility",
                locale: locale
            )
            let accessibilityLabel = String(
                format: rowFormat,
                locale: locale,
                pluralName,
                daysText,
                sharePercentText
            )

            return InsightsWeekdayRowModel(
                weekday: entry.weekday,
                shortName: shortName,
                pluralName: pluralName,
                drinkingDays: entry.drinkingDays,
                share: entry.shareOfDrinkingDays,
                sharePercentText: sharePercentText,
                isTop: isTop,
                accessibilityLabel: accessibilityLabel
            )
        }

        return (topSentence, rows)
    }

    static func buildDrinkTypes(
        from drinkTypes: [DrinkTypeTotal],
        displayUnit: DisplayUnit,
        locale: Locale = .current
    ) -> [InsightsDrinkTypeRowModel] {
        drinkTypes.map { item in
            let id = item.presetKey ?? "custom:\(item.name)"
            let localizedName = PresetPresentation.localizedName(
                presetKey: item.presetKey,
                fallbackName: item.name,
                locale: locale
            )
            let symbolName = PresetPresentation.symbolName(
                presetKey: item.presetKey,
                fallbackSymbol: "wineglass"
            )
            let countText = AppLocalization.plural(
                "insights.drinkType.count",
                count: item.drinkCount,
                locale: locale
            )
            let primaryAmountText = AmountFormatting.formattedValue(
                grams: item.grams,
                hu: item.hu,
                in: displayUnit,
                locale: locale
            )
            let gramsText = AmountFormatting.formattedGrams(item.grams, locale: locale)

            return InsightsDrinkTypeRowModel(
                id: id,
                name: localizedName,
                symbolName: symbolName,
                count: item.drinkCount,
                countText: countText,
                hu: item.hu,
                grams: item.grams,
                primaryAmountText: primaryAmountText,
                gramsText: gramsText
            )
        }
    }

    private static func buildHeatmapSummaryAccessibility(
        stats: PeriodStats,
        locale: Locale
    ) -> String {
        let format = AppLocalization.string(
            "insights.heatmap.summary.accessibility",
            locale: locale
        )
        return String(
            format: format,
            locale: locale,
            Int64(stats.drinkingDays),
            Int64(stats.trackedDays)
        )
    }

    private static func buildWeeklySummaryAccessibility(
        weeksCount: Int,
        stats: PeriodStats,
        displayUnit: DisplayUnit,
        locale: Locale
    ) -> String {
        let totalText = AmountFormatting.formattedValue(
            grams: stats.totalGrams,
            hu: stats.totalHU,
            in: displayUnit,
            locale: locale
        )
        let format = AppLocalization.string("insights.weekly.summary.accessibility", locale: locale)
        return String(format: format, locale: locale, Int64(weeksCount), totalText)
    }

    static func pluralWeekdayName(for weekday: Weekday, locale: Locale = .current) -> String {
        let key: String =
            switch weekday {
            case .monday:
                "insights.weekday.plural.monday"
            case .tuesday:
                "insights.weekday.plural.tuesday"
            case .wednesday:
                "insights.weekday.plural.wednesday"
            case .thursday:
                "insights.weekday.plural.thursday"
            case .friday:
                "insights.weekday.plural.friday"
            case .saturday:
                "insights.weekday.plural.saturday"
            case .sunday:
                "insights.weekday.plural.sunday"
            }
        return AppLocalization.string(key, locale: locale)
    }

    static func shortWeekdayName(for weekday: Weekday, locale: Locale = .current) -> String {
        // 2026-10-19 is a Monday
        let referenceMonday = LogicalDay(year: 2026, month: 10, day: 19)
        let targetDay = referenceMonday.adding(days: weekday.rawValue - 1)
        let date = logicalDayToUTCDate(targetDay)

        guard let utc = TimeZone(identifier: "UTC") else {
            return pluralWeekdayName(for: weekday, locale: locale)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        calendar.locale = locale

        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = utc
        return date.formatted(style)
    }

    static func logicalDayToUTCDate(_ day: LogicalDay) -> Date {
        guard let utc = TimeZone(identifier: "UTC") else {
            return Date(timeIntervalSince1970: 0)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let components = DateComponents(
            calendar: calendar,
            timeZone: utc,
            year: day.year,
            month: day.month,
            day: day.day,
            hour: 12
        )
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private static func startOfMondayWeek(for day: LogicalDay) -> LogicalDay {
        let offset = (day.weekday.rawValue - Weekday.monday.rawValue + 7) % 7
        return day.adding(days: -offset)
    }
}
