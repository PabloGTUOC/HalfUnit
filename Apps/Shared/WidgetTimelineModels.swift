import Foundation
import HalfUnitCore

struct WidgetPresetButtonModel: Identifiable, Equatable, Sendable {
    let id: UUID
    let entity: PresetEntity
    let localizedName: String
    let symbolName: String
    let huText: String
    let accessibilityLabel: String

    init(
        entity: PresetEntity,
        displayUnit: DisplayUnit = .hu,
        locale: Locale = .current
    ) {
        self.id = entity.id
        self.entity = entity
        self.localizedName = PresetPresentation.localizedName(
            presetKey: entity.key,
            fallbackName: entity.name,
            locale: locale
        )
        self.symbolName = PresetPresentation.symbolName(
            presetKey: entity.key,
            fallbackSymbol: entity.symbolName
        )
        let grams = Units.grams(volumeMl: entity.volumeMl, abvPercent: entity.abvPercent)
        self.huText = PresetPresentation.formattedDisplayValue(
            grams: grams,
            hu: entity.hu,
            in: displayUnit,
            locale: locale
        )
        self.accessibilityLabel = PresetPresentation.accessibilityLabel(
            presetKey: entity.key,
            fallbackName: entity.name,
            hu: entity.hu,
            locale: locale
        )
    }
}

struct WidgetEntrySnapshot: Equatable, Sendable {
    static let maxMediumPresetButtons = 3

    let currentStreakDays: Int
    let isDrinkingToday: Bool
    let todayTotalHU: Decimal
    let todayTotalHUText: String
    let previousStreakDays: Int?
    let previousStreakText: String?
    let streakHeadline: String
    let streakAccessibilityLabel: String
    let watchShortDaysText: String
    let watchDaysHeadlineText: String
    let watchSubtitleText: String
    let lastDrinkSubtitle: String
    let presetButtons: [WidgetPresetButtonModel]

    init(
        summary: StreakSummary,
        todayTotalHU: Decimal,
        todayTotalGrams: Decimal = Decimal(0),
        displayUnit: DisplayUnit = .hu,
        presets: [PresetEntity],
        locale: Locale = .current
    ) {
        let drinkingToday = summary.isDrinkingToday || todayTotalHU > Decimal(0)
        self.currentStreakDays = summary.currentStreakDays
        self.isDrinkingToday = drinkingToday
        self.todayTotalHU = todayTotalHU
        let formattedTodayHU = PresetPresentation.formattedHU(todayTotalHU, locale: locale)
        self.todayTotalHUText = PresetPresentation.formattedDisplayValue(
            grams: todayTotalGrams,
            hu: todayTotalHU,
            in: displayUnit,
            locale: locale
        )
        self.previousStreakDays = summary.previousStreakDays

        if let previousDays = summary.previousStreakDays, drinkingToday {
            self.previousStreakText = AppLocalization.plural(
                "streak.previousStreak",
                count: previousDays,
                locale: locale
            )
        } else {
            self.previousStreakText = nil
        }

        if drinkingToday {
            self.streakHeadline = AppLocalization.string("streak.today", locale: locale)
        } else {
            self.streakHeadline = AppLocalization.plural(
                "streak.daysWithoutAlcohol",
                count: summary.currentStreakDays,
                locale: locale
            )
        }

        self.streakAccessibilityLabel = AppLocalization.plural(
            "streak.daysWithoutAlcohol",
            count: summary.currentStreakDays,
            locale: locale
        )

        let shortDayFormat = AppLocalization.string("widget.watch.shortDays", locale: locale)
        self.watchShortDaysText = String(
            format: shortDayFormat,
            locale: locale,
            Int64(summary.currentStreakDays)
        )

        self.watchDaysHeadlineText = AppLocalization.plural(
            "watch.header.days",
            count: summary.currentStreakDays,
            locale: locale
        )

        if drinkingToday {
            let todayFormat = AppLocalization.string("watch.header.todayHU", locale: locale)
            self.watchSubtitleText = String(format: todayFormat, locale: locale, formattedTodayHU)
        } else {
            self.watchSubtitleText = AppLocalization.string(
                "widget.watch.withoutAlcohol",
                locale: locale
            )
        }

        if let lastDrink = summary.lastDrink {
            let dateString = Self.formatLogicalDay(lastDrink.logicalDay, locale: locale)
            let drinkName = PresetPresentation.localizedName(
                presetKey: lastDrink.presetKey,
                fallbackName: lastDrink.name,
                locale: locale
            )
            let format = AppLocalization.string("streak.lastDrink", locale: locale)
            self.lastDrinkSubtitle = String(format: format, locale: locale, dateString, drinkName)
        } else {
            self.lastDrinkSubtitle = AppLocalization.string("streak.empty", locale: locale)
        }

        let effectivePresets =
            presets.isEmpty
            ? PresetEntity.fallbackDefaultEntities
            : presets
        self.presetButtons =
            effectivePresets
            .prefix(Self.maxMediumPresetButtons)
            .map { WidgetPresetButtonModel(entity: $0, displayUnit: displayUnit, locale: locale) }
    }

    static func placeholder(locale: Locale = .current) -> WidgetEntrySnapshot {
        let placeholderSummary = StreakSummary(
            lastDrinkingDay: nil,
            lastDrink: nil,
            isDrinkingToday: false,
            currentStreakDays: 24,
            previousStreakDays: nil,
            longestStreakEver: 24,
            longestStreakThisYear: 24
        )
        return WidgetEntrySnapshot(
            summary: placeholderSummary,
            todayTotalHU: Decimal(0),
            presets: PresetEntity.fallbackDefaultEntities,
            locale: locale
        )
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

struct WidgetTimelineSlice: Equatable, Sendable {
    let date: Date
    let snapshot: WidgetEntrySnapshot
}

struct WidgetTimelinePlan: Equatable, Sendable {
    let entries: [WidgetTimelineSlice]
    let reloadAfterDate: Date

    @MainActor
    static func build(
        from logService: LogService,
        now: Date,
        timeZone: TimeZone,
        locale: Locale = .current
    ) throws -> WidgetTimelinePlan {
        try logService.seedDefaultPresetsIfNeeded()
        let settings = try logService.settings()
        let boundaryHour = DayBoundaryScheduler.resolvedBoundaryHour(settings.dayBoundaryHour)
        let snapshots = try logService.snapshots()
        let presetEntities = try logService.presets().map(PresetEntity.init(preset:))

        let entryDates = DayBoundaryScheduler.timelineEntryDates(
            now: now,
            boundaryHour: boundaryHour,
            timeZone: timeZone
        )
        let nextBoundary =
            entryDates.last
            ?? DayBoundaryScheduler.nextBoundaryDate(
                now: now,
                boundaryHour: boundaryHour,
                timeZone: timeZone
            )

        let slices: [WidgetTimelineSlice] = entryDates.map { entryDate in
            let logicalDay = LogicalDay.of(
                entryDate,
                boundaryHour: boundaryHour,
                timeZone: timeZone
            )
            let engine = StatsEngine(
                drinks: snapshots,
                firstUseDay: settings.firstUseDay,
                today: logicalDay
            )
            let streakSummary = engine.streaks()
            let todaysDrinks = snapshots.filter { $0.deletedAt == nil && $0.logicalDay == logicalDay }
            let todayTotalHU = todaysDrinks.reduce(Decimal(0)) { $0 + $1.hu }
            let todayTotalGrams = todaysDrinks.reduce(Decimal(0)) { $0 + $1.grams }

            let snapshot = WidgetEntrySnapshot(
                summary: streakSummary,
                todayTotalHU: todayTotalHU,
                todayTotalGrams: todayTotalGrams,
                displayUnit: settings.displayUnit,
                presets: presetEntities,
                locale: locale
            )
            return WidgetTimelineSlice(date: entryDate, snapshot: snapshot)
        }

        return WidgetTimelinePlan(entries: slices, reloadAfterDate: nextBoundary)
    }
}
