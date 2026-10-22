import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("App Intents Logic Tests")
struct IntentsTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")
    private static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!
    private static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test("PresetEntity and PresetEntityQuery map presets, resolve IDs, and localize in en and de")
    @MainActor
    func presetEntityQueryMapping() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let nowDate = Self.makeDate(2026, 10, 22, 20, 0, in: Self.berlinTimeZone)
        let service = LogService(
            context: container.mainContext,
            now: { nowDate },
            timeZone: { Self.berlinTimeZone }
        )

        let allEntities = try PresetEntityQuery.allEntities(from: service)
        #expect(allEntities.count == 6)

        let beerEntity = try #require(allEntities.first(where: { $0.key == "beer" }))
        #expect(beerEntity.localizedName(locale: Self.englishLocale) == "Beer")
        #expect(beerEntity.localizedName(locale: Self.germanLocale) == "Bier")
        #expect(beerEntity.formattedHU(locale: Self.englishLocale) == "1 HU")
        #expect(beerEntity.resolvedSymbolName == "mug.fill")

        let smallBeerEntity = try #require(allEntities.first(where: { $0.key == "smallBeer" }))
        #expect(smallBeerEntity.localizedName(locale: Self.englishLocale) == "Small beer")
        #expect(smallBeerEntity.localizedName(locale: Self.germanLocale) == "Kleines Bier")
        #expect(smallBeerEntity.formattedHU(locale: Self.englishLocale) == "0.5 HU")
        #expect(smallBeerEntity.formattedHU(locale: Self.germanLocale) == "0,5 HU")

        // Lookup by real UUIDs preserves requested order
        let queried = try PresetEntityQuery.entities(
            for: [beerEntity.id, smallBeerEntity.id],
            from: service
        )
        #expect(queried.map(\.key) == ["beer", "smallBeer"])

        // Lookup by fallback default UUID also resolves to the seeded store preset
        let fallbackBeerID = try #require(PresetEntity.fallbackDefaultIDsByKey["beer"])
        let fallbackResolved = try PresetEntityQuery.entities(
            for: [fallbackBeerID],
            from: service
        )
        #expect(fallbackResolved.count == 1)
        #expect(fallbackResolved.first?.id == beerEntity.id)
    }

    @Test(
        "LogDrinkIntent.performLog logs with .siri and .widget sources, respects 01:30 boundary on DST week, and localizes result"
    )
    @MainActor
    func logDrinkIntentExecution() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let currentNow = LockIsolated(Self.makeDate(2026, 3, 28, 21, 0, in: Self.berlinTimeZone))
        let currentZone = LockIsolated(Self.berlinTimeZone)
        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )

        let entities = try PresetEntityQuery.allEntities(from: service)
        let beerEntity = try #require(entities.first(where: { $0.key == "beer" }))
        let smallWineEntity = try #require(entities.first(where: { $0.key == "smallWine" }))

        // 1. Log via Siri at 01:30 on DST spring-forward Sunday (2026-03-29 in Europe/Berlin)
        let lateNight = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        currentNow.setValue(lateNight)

        let (siriDrink, siriDialogEn) = try LogDrinkIntent.performLog(
            preset: beerEntity,
            time: nil,
            source: .siri,
            logService: service,
            locale: Self.englishLocale
        )
        #expect(siriDrink.source == .siri)
        #expect(siriDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))
        #expect(siriDialogEn == "Logged Beer (1 HU).")

        // 2. Log via Widget button in German locale
        let (widgetDrink, widgetDialogDe) = try LogDrinkIntent.performLog(
            preset: smallWineEntity,
            time: lateNight,
            source: .widget,
            logService: service,
            locale: Self.germanLocale
        )
        #expect(widgetDrink.source == .widget)
        #expect(widgetDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))
        #expect(widgetDialogDe == "Kleiner Wein protokolliert (0,5 HU).")

        let activeDrinks = try service.drinks(includeDeleted: false)
        #expect(activeDrinks.count == 2)
    }

    @Test(
        "GetStreakIntent and GetStatsIntent handle 07:00 boundary, 01:30 drink, DST week, time-zone change, and localize results"
    )
    @MainActor
    func getStreakAndGetStatsIntents() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let currentNow = LockIsolated(Self.makeDate(2026, 3, 28, 20, 0, in: Self.berlinTimeZone))
        let currentZone = LockIsolated(Self.berlinTimeZone)
        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )

        let entities = try PresetEntityQuery.allEntities(from: service)
        let beerEntity = try #require(entities.first(where: { $0.key == "beer" }))

        // Initial empty store on Saturday 2026-03-28 -> 1 day without alcohol
        let (_, initialStreakEn) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.englishLocale
        )
        #expect(initialStreakEn == "1 day without alcohol.")
        let (_, initialStreakDe) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.germanLocale
        )
        #expect(initialStreakDe == "1 Tag ohne Alkohol.")

        // Log at 01:30 on Sunday 2026-03-29 (DST spring-forward day, still logical Saturday 2026-03-28)
        currentNow.setValue(Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone))
        _ = try LogDrinkIntent.performLog(
            preset: beerEntity,
            source: .siri,
            logService: service,
            locale: Self.englishLocale
        )

        // At 06:59 on Sunday 2026-03-29, still logical Saturday (drinking today)
        currentNow.setValue(Self.makeDate(2026, 3, 29, 6, 59, in: Self.berlinTimeZone))
        let (beforeBoundarySummary, beforeBoundaryTextEn) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.englishLocale
        )
        #expect(beforeBoundarySummary.isDrinkingToday)
        #expect(beforeBoundaryTextEn == "Drink logged today. Previous streak: 0 days.")

        // At 07:00 on Sunday 2026-03-29 (after DST jump), logical day flips to Sunday -> 1 day without alcohol
        currentNow.setValue(Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        let (afterBoundarySummary, afterBoundaryTextEn) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.englishLocale
        )
        #expect(!afterBoundarySummary.isDrinkingToday)
        #expect(afterBoundarySummary.currentStreakDays == 1)
        #expect(afterBoundaryTextEn == "1 day without alcohol.")

        // Move to Monday 2026-03-30 in Asia/Tokyo -> 2 days without alcohol
        currentZone.setValue(Self.tokyoTimeZone)
        currentNow.setValue(Self.makeDate(2026, 3, 30, 12, 0, in: Self.tokyoTimeZone))
        let (mondaySummary, mondayTextEn) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.englishLocale
        )
        #expect(mondaySummary.currentStreakDays == 2)
        #expect(mondayTextEn == "2 days without alcohol.")
        let (_, mondayTextDe) = try GetStreakIntent.evaluateStreak(
            logService: service,
            locale: Self.germanLocale
        )
        #expect(mondayTextDe == "2 Tage ohne Alkohol.")

        // Stats for 3m when only 3 days are tracked -> "1 of 3 tracked days with alcohol (2 alcohol-free days, 1 HU total)."
        let (stats3m, stats3mTextEn) = try GetStatsIntent.evaluateStats(
            period: .last3Months,
            logService: service,
            locale: Self.englishLocale
        )
        #expect(stats3m.drinkingDays == 1)
        #expect(stats3m.trackedDays == 3)
        #expect(
            stats3mTextEn == "1 of 3 tracked days with alcohol (2 alcohol-free days, 1 HU total)."
        )

        let (_, stats3mTextDe) = try GetStatsIntent.evaluateStats(
            period: .last3Months,
            logService: service,
            locale: Self.germanLocale
        )
        #expect(
            stats3mTextDe
                == "1 von 3 erfassten Tagen mit Alkohol (2 alkoholfreie Tage, 1 HU gesamt)."
        )

        // When firstUseDay covers the full 7-day window -> "1 of 7 days with alcohol (6 alcohol-free days, 1 HU total)."
        let settings = try service.settings()
        settings.firstUseDay = LogicalDay(year: 2026, month: 3, day: 1)
        let (_, stats7dTextEn) = try GetStatsIntent.evaluateStats(
            period: .last7Days,
            logService: service,
            locale: Self.englishLocale
        )
        #expect(stats7dTextEn == "1 of 7 days with alcohol (6 alcohol-free days, 1 HU total).")

        let (_, stats7dTextDe) = try GetStatsIntent.evaluateStats(
            period: .last7Days,
            logService: service,
            locale: Self.germanLocale
        )
        #expect(stats7dTextDe == "1 von 7 Tagen mit Alkohol (6 alkoholfreie Tage, 1 HU gesamt).")
    }

    private static func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components)!
    }
}

private final class LockIsolated<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        self.storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func setValue(_ newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        storage = newValue
    }
}
