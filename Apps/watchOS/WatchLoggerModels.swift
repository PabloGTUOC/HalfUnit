import Foundation
import HalfUnitCore

enum WatchEarlierOffset: Int, CaseIterable, Identifiable, Sendable {
    case minutes15 = 15
    case minutes30 = 30
    case hours1 = 60
    case hours2 = 120
    case hours3 = 180

    var id: Int { rawValue }

    var seconds: TimeInterval {
        TimeInterval(rawValue * 60)
    }

    var catalogKey: String {
        switch self {
        case .minutes15:
            "watch.logEarlier.offset.15m"
        case .minutes30:
            "watch.logEarlier.offset.30m"
        case .hours1:
            "watch.logEarlier.offset.1h"
        case .hours2:
            "watch.logEarlier.offset.2h"
        case .hours3:
            "watch.logEarlier.offset.3h"
        }
    }

    func targetTimestamp(from now: Date) -> Date {
        now.addingTimeInterval(-seconds)
    }

    func localizedTitle(locale: Locale = .current) -> String {
        AppLocalization.string(catalogKey, locale: locale)
    }

    func accessibilityLabel(
        presetKey: String?,
        fallbackName: String,
        locale: Locale = .current
    ) -> String {
        let displayName = PresetPresentation.localizedName(
            presetKey: presetKey,
            fallbackName: fallbackName,
            locale: locale
        )
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let spokenName = languageCode == "de" ? displayName : displayName.lowercased(with: locale)
        let offsetTitle = localizedTitle(locale: locale)
        let format = AppLocalization.string("watch.logEarlier.offset.accessibility", locale: locale)
        return String(format: format, locale: locale, spokenName, offsetTitle)
    }
}

struct WatchDrinkRowModel: Identifiable, Equatable, Sendable {
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

struct WatchLoggerSnapshot: Equatable, Sendable {
    let headerText: String
    let headerAccessibilityLabel: String
    let isDrinkingToday: Bool
    let currentStreakDays: Int
    let todayTotalHU: Decimal
    let todayDrinks: [WatchDrinkRowModel]
    let mostRecentTodayDrinkId: UUID?
    let dayBoundaryHour: Int

    init(
        streakSummary: StreakSummary,
        todayDrinks: [WatchDrinkRowModel],
        todayTotalHU: Decimal,
        dayBoundaryHour: Int = LogicalDay.defaultBoundaryHour,
        locale: Locale = .current
    ) {
        let drinkingToday = streakSummary.isDrinkingToday || !todayDrinks.isEmpty
        self.isDrinkingToday = drinkingToday
        self.currentStreakDays = streakSummary.currentStreakDays
        self.todayTotalHU = todayTotalHU
        self.todayDrinks = todayDrinks
        self.mostRecentTodayDrinkId = todayDrinks.first?.id
        self.dayBoundaryHour = DayBoundaryScheduler.resolvedBoundaryHour(dayBoundaryHour)

        if drinkingToday {
            let formattedTotal = PresetPresentation.formattedHU(todayTotalHU, locale: locale)
            let format = AppLocalization.string("watch.header.todayHU", locale: locale)
            let headline = String(format: format, locale: locale, formattedTotal)
            self.headerText = headline
            self.headerAccessibilityLabel = headline
        } else {
            self.headerText = AppLocalization.plural(
                "watch.header.days",
                count: streakSummary.currentStreakDays,
                locale: locale
            )
            self.headerAccessibilityLabel = AppLocalization.plural(
                "streak.daysWithoutAlcohol",
                count: streakSummary.currentStreakDays,
                locale: locale
            )
        }
    }

    @MainActor
    static func load(from logService: LogService, locale: Locale = .current) throws -> WatchLoggerSnapshot {
        let currentSettings = try logService.settings()
        let currentToday = try logService.today()
        let snapshots = try logService.snapshots()
        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: currentSettings.firstUseDay,
            today: currentToday
        )
        let streakSummary = engine.streaks()

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
        var rows: [WatchDrinkRowModel] = []
        rows.reserveCapacity(todaysDrinks.count)

        for drink in todaysDrinks {
            totalHU += drink.hu
            let presetKey = drink.presetId.flatMap { presetKeyById[$0] }
            rows.append(
                WatchDrinkRowModel(
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

        return WatchLoggerSnapshot(
            streakSummary: streakSummary,
            todayDrinks: rows,
            todayTotalHU: totalHU,
            dayBoundaryHour: currentSettings.dayBoundaryHour,
            locale: locale
        )
    }
}
