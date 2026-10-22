import Foundation
import HalfUnitCore

struct StreakCardModel: Equatable, Sendable {
    let headline: String
    let previousStreakText: String?
    let subtitle: String
    let isDrinkingToday: Bool
    let isEmptyState: Bool

    init(summary: StreakSummary, locale: Locale = .current) {
        self.isDrinkingToday = summary.isDrinkingToday
        self.isEmptyState = (summary.lastDrink == nil)

        if summary.isDrinkingToday {
            self.headline = AppLocalization.string("streak.today", locale: locale)
            if let previousDays = summary.previousStreakDays {
                self.previousStreakText = AppLocalization.plural(
                    "streak.previousStreak",
                    count: previousDays,
                    locale: locale
                )
            } else {
                self.previousStreakText = nil
            }
        } else {
            self.headline = AppLocalization.plural(
                "streak.daysWithoutAlcohol",
                count: summary.currentStreakDays,
                locale: locale
            )
            self.previousStreakText = nil
        }

        if let lastDrink = summary.lastDrink {
            let dateString = Self.formatLogicalDay(lastDrink.logicalDay, locale: locale)
            let drinkName = PresetPresentation.localizedName(
                presetKey: lastDrink.presetKey,
                fallbackName: lastDrink.name,
                locale: locale
            )
            let format = AppLocalization.string("streak.lastDrink", locale: locale)
            self.subtitle = String(format: format, locale: locale, dateString, drinkName)
        } else {
            self.subtitle = AppLocalization.string("streak.empty", locale: locale)
        }
    }

    static func formatLogicalDay(_ day: LogicalDay, locale: Locale = .current) -> String {
        guard let utcTimeZone = TimeZone(identifier: "UTC") else {
            return "\(day.year)-\(day.month)-\(day.day)"
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utcTimeZone
        calendar.locale = locale

        let components = DateComponents(
            calendar: calendar,
            timeZone: utcTimeZone,
            year: day.year,
            month: day.month,
            day: day.day,
            hour: 12
        )
        guard let date = calendar.date(from: components) else {
            return "\(day.year)-\(day.month)-\(day.day)"
        }

        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.abbreviated)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = utcTimeZone
        return date.formatted(style)
    }
}

struct TodayDrinkRowModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let timeText: String
    let hu: Decimal
    let huText: String

    init(
        id: UUID,
        presetKey: String?,
        rawName: String,
        timestamp: Date,
        timeZone: TimeZone,
        hu: Decimal,
        locale: Locale = .current
    ) {
        self.id = id
        self.name = PresetPresentation.localizedName(
            presetKey: presetKey,
            fallbackName: rawName,
            locale: locale
        )
        self.timeText = Self.formatTime(timestamp, timeZone: timeZone, locale: locale)
        self.hu = hu
        self.huText = PresetPresentation.formattedHU(hu, locale: locale)
    }

    static func formatTime(_ timestamp: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale

        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = timeZone
        return timestamp.formatted(style)
    }
}

struct TodayScreenSnapshot: Equatable, Sendable {
    let streakCard: StreakCardModel
    let todayDrinks: [TodayDrinkRowModel]
    let todayTotalHU: Decimal
    let todayTotalText: String

    @MainActor
    static func load(from logService: LogService, locale: Locale = .current) throws -> TodayScreenSnapshot {
        let currentSettings = try logService.settings()
        let currentToday = try logService.today()
        let snapshots = try logService.snapshots()
        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: currentSettings.firstUseDay,
            today: currentToday
        )
        let streakSummary = engine.streaks()
        let streakCard = StreakCardModel(summary: streakSummary, locale: locale)

        let presets = try logService.presets()
        var presetKeyById: [UUID: String] = [:]
        for preset in presets {
            if let key = preset.key {
                presetKeyById[preset.id] = key
            }
        }

        let allActiveDrinks = try logService.drinks(includeDeleted: false)
        let todaysDrinks = allActiveDrinks.filter { $0.logicalDay == currentToday }

        var totalHU = Decimal(0)
        var rows: [TodayDrinkRowModel] = []
        rows.reserveCapacity(todaysDrinks.count)

        for drink in todaysDrinks {
            totalHU += drink.hu
            let presetKey = drink.presetId.flatMap { presetKeyById[$0] }
            rows.append(
                TodayDrinkRowModel(
                    id: drink.id,
                    presetKey: presetKey,
                    rawName: drink.name,
                    timestamp: drink.timestamp,
                    timeZone: drink.timeZone,
                    hu: drink.hu,
                    locale: locale
                )
            )
        }

        let formattedTotalHU = PresetPresentation.formattedHU(totalHU, locale: locale)
        let totalFormat = AppLocalization.string("today.drinks.total", locale: locale)
        let todayTotalText = String(format: totalFormat, locale: locale, formattedTotalHU)

        return TodayScreenSnapshot(
            streakCard: streakCard,
            todayDrinks: rows,
            todayTotalHU: totalHU,
            todayTotalText: todayTotalText
        )
    }
}
