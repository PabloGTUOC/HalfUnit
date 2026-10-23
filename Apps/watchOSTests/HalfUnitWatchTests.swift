import Foundation
import HalfUnitCore
import SwiftData
import Testing

@testable import HalfUnitWatch

@Suite("HalfUnit watchOS Logger Tests")
struct HalfUnitWatchTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")
    private static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!
    private static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test("WatchPresetPresentation maps preset keys to localized names, symbols, and accessibility labels")
    func presetPresentationMappingsAndAccessibility() {
        let expected: [(String, String, String, String, String)] = [
            ("smallBeer", "preset.smallBeer", "Small beer", "Kleines Bier", "halfunit.beer.bottle"),
            ("smallWine", "preset.smallWine", "Small wine", "Kleiner Wein", "halfunit.wine.small"),
            ("beer", "preset.beer", "Beer", "Bier", "halfunit.beer.mug"),
            ("wineGlass", "preset.wineGlass", "Wine glass", "Glas Wein", "halfunit.wine.glass"),
            ("shot", "preset.shot", "Shot", "Schnaps", "halfunit.shot"),
            ("longDrink", "preset.longDrink", "Long drink", "Longdrink", "halfunit.longdrink"),
        ]

        for (key, catalogKey, enName, deName, symbol) in expected {
            #expect(WatchPresetPresentation.catalogKey(for: key) == catalogKey)
            #expect(
                WatchPresetPresentation.localizedName(
                    presetKey: key,
                    fallbackName: key,
                    locale: Self.englishLocale
                ) == enName
            )
            #expect(
                WatchPresetPresentation.localizedName(
                    presetKey: key,
                    fallbackName: key,
                    locale: Self.germanLocale
                ) == deName
            )
            #expect(
                WatchPresetPresentation.symbolName(presetKey: key, fallbackSymbol: "questionmark") == symbol
            )
        }

        let beerEn = WatchPresetPresentation.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            hu: Decimal(1),
            locale: Self.englishLocale
        )
        #expect(beerEn == "Log beer, 1 unit")

        let smallBeerEn = WatchPresetPresentation.accessibilityLabel(
            presetKey: "smallBeer",
            fallbackName: "smallBeer",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            locale: Self.englishLocale
        )
        #expect(smallBeerEn == "Log small beer, 0.5 units")

        let beerDe = WatchPresetPresentation.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            hu: Decimal(1),
            locale: Self.germanLocale
        )
        #expect(beerDe == "Bier protokollieren, 1 Einheit")

        let smallBeerDe = WatchPresetPresentation.accessibilityLabel(
            presetKey: "smallBeer",
            fallbackName: "smallBeer",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            locale: Self.germanLocale
        )
        #expect(smallBeerDe == "Kleines Bier protokollieren, 0,5 Einheiten")
    }

    @Test("EarlierOffset computes target timestamps and localizes titles and accessibility labels")
    func earlierOffsets() {
        let baseDate = Self.makeDate(2026, 10, 22, 22, 0, in: Self.berlinTimeZone)

        #expect(EarlierOffset.minutes15.seconds == 900)
        #expect(EarlierOffset.minutes30.seconds == 1800)
        #expect(EarlierOffset.hours1.seconds == 3600)
        #expect(EarlierOffset.hours2.seconds == 7200)
        #expect(EarlierOffset.hours3.seconds == 10_800)

        #expect(
            EarlierOffset.minutes15.targetTimestamp(from: baseDate)
                == Self.makeDate(2026, 10, 22, 21, 45, in: Self.berlinTimeZone)
        )
        #expect(
            EarlierOffset.hours3.targetTimestamp(from: baseDate)
                == Self.makeDate(2026, 10, 22, 19, 0, in: Self.berlinTimeZone)
        )

        #expect(EarlierOffset.minutes15.localizedTitle(locale: Self.englishLocale) == "15 min ago")
        #expect(EarlierOffset.minutes15.localizedTitle(locale: Self.germanLocale) == "vor 15 Min.")
        #expect(EarlierOffset.hours2.localizedTitle(locale: Self.englishLocale) == "2 h ago")
        #expect(EarlierOffset.hours2.localizedTitle(locale: Self.germanLocale) == "vor 2 Std.")

        let a11yEn = EarlierOffset.minutes30.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            locale: Self.englishLocale
        )
        #expect(a11yEn == "Log beer, 30 min ago")

        let a11yDe = EarlierOffset.minutes30.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            locale: Self.germanLocale
        )
        #expect(a11yDe == "Bier protokollieren, vor 30 Min.")
    }

    @Test("WatchDayBoundary handles 07:00 boundary, 01:30 drink, DST transitions, and time-zone changes")
    func dayBoundaryCalculations() {
        // 01:30 on DST spring-forward Sunday (2026-03-29 in Europe/Berlin):
        // Clocks jump from 02:00 CET (+01:00) to 03:00 CEST (+02:00).
        // Logical day at 01:30 is Saturday 2026-03-28; next boundary is Sunday 2026-03-29 07:00 CEST (4.5 hours later).
        let springLateNight = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        #expect(
            WatchDayBoundary.currentLogicalDay(
                at: springLateNight,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == LogicalDay(year: 2026, month: 3, day: 28)
        )
        let springNextBoundary = WatchDayBoundary.nextBoundaryDate(
            after: springLateNight,
            boundaryHour: 7,
            timeZone: Self.berlinTimeZone
        )
        #expect(springNextBoundary == Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        #expect(
            WatchDayBoundary.secondsUntilNextBoundary(
                from: springLateNight,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == 4.5 * 3600
        )

        // Exactly at 07:00 on 2026-03-29: logical day is 2026-03-29; next boundary is Monday 2026-03-30 07:00.
        let atBoundary = Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone)
        #expect(
            WatchDayBoundary.currentLogicalDay(
                at: atBoundary,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == LogicalDay(year: 2026, month: 3, day: 29)
        )
        #expect(
            WatchDayBoundary.nextBoundaryDate(
                after: atBoundary,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == Self.makeDate(2026, 3, 30, 7, 0, in: Self.berlinTimeZone)
        )

        // DST fall-back weekend (2026-10-24 23:00 CEST to 2026-10-25 07:00 CET is 9 hours).
        let fallBackEvening = Self.makeDate(2026, 10, 24, 23, 0, in: Self.berlinTimeZone)
        #expect(
            WatchDayBoundary.secondsUntilNextBoundary(
                from: fallBackEvening,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == 9 * 3600
        )

        // Time-zone change to Asia/Tokyo at the same absolute instant:
        // 2026-03-29 01:30 CET (+01:00) is 2026-03-29 09:30 JST (+09:00), which is already after 07:00 in Tokyo!
        #expect(
            WatchDayBoundary.currentLogicalDay(
                at: springLateNight,
                boundaryHour: 7,
                timeZone: Self.tokyoTimeZone
            ) == LogicalDay(year: 2026, month: 3, day: 29)
        )
        #expect(
            WatchDayBoundary.nextBoundaryDate(
                after: springLateNight,
                boundaryHour: 7,
                timeZone: Self.tokyoTimeZone
            ) == Self.makeDate(2026, 3, 30, 7, 0, in: Self.tokyoTimeZone)
        )
        #expect(
            DayBoundaryScheduler.timelineEntryDates(
                now: springLateNight,
                boundaryHour: 7,
                timeZone: Self.berlinTimeZone
            ) == [springLateNight, springNextBoundary]
        )
    }

    @Test("WatchLoggerSnapshot formats streak days, Today HU total, 01:30 drink, DST week, time-zone change, and undo")
    @MainActor
    func watchLoggerSnapshotLifecycle() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let currentNow = LockIsolated(Self.makeDate(2026, 3, 28, 21, 0, in: Self.berlinTimeZone))
        let currentZone = LockIsolated(Self.berlinTimeZone)

        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )
        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let beerPreset = try #require(presets.first(where: { $0.key == "beer" }))
        let smallWinePreset = try #require(presets.first(where: { $0.key == "smallWine" }))

        // Initial empty state on first use day: "1 day" / "1 Tag"
        let initialEn = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(!initialEn.isDrinkingToday)
        #expect(initialEn.headerText == "1 day")
        #expect(initialEn.headerAccessibilityLabel == "1 day without alcohol")
        #expect(initialEn.mostRecentTodayDrinkId == nil)

        let initialDe = try WatchLoggerSnapshot.load(from: service, locale: Self.germanLocale)
        #expect(initialDe.headerText == "1 Tag")
        #expect(initialDe.headerAccessibilityLabel == "1 Tag ohne Alkohol")

        // Log a drink at 01:30 on Sunday 2026-03-29 (DST spring-forward day) from .watch:
        // Assigned to Saturday 2026-03-28.
        currentNow.setValue(Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone))
        let lateDrink = try service.log(preset: beerPreset, source: .watch)
        #expect(lateDrink.source == .watch)
        #expect(lateDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))

        // At 06:59 on Sunday 2026-03-29, logical today is still 2026-03-28.
        currentNow.setValue(Self.makeDate(2026, 3, 29, 6, 59, in: Self.berlinTimeZone))
        let beforeBoundary = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(beforeBoundary.isDrinkingToday)
        #expect(beforeBoundary.headerText == "Today: 1 HU")
        #expect(beforeBoundary.todayDrinks.count == 1)
        #expect(beforeBoundary.mostRecentTodayDrinkId == lateDrink.id)

        // At 07:00 on Sunday 2026-03-29, logical today advances to 2026-03-29 (1 day without alcohol).
        currentNow.setValue(Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        let afterBoundary = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(!afterBoundary.isDrinkingToday)
        #expect(afterBoundary.headerText == "1 day")
        #expect(afterBoundary.todayDrinks.isEmpty)
        #expect(afterBoundary.mostRecentTodayDrinkId == nil)

        // Advance to Monday 2026-03-30 in Asia/Tokyo: Saturday -> Monday streak is 2 days.
        currentZone.setValue(Self.tokyoTimeZone)
        currentNow.setValue(Self.makeDate(2026, 3, 30, 20, 0, in: Self.tokyoTimeZone))
        let mondayEn = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(mondayEn.headerText == "2 days")
        let mondayDe = try WatchLoggerSnapshot.load(from: service, locale: Self.germanLocale)
        #expect(mondayDe.headerText == "2 Tage")

        // Log Beer (1 HU) and Small wine earlier (30 min ago, 0.5 HU) -> Today: 1.5 HU
        let mondayBeer = try service.log(preset: beerPreset, source: .watch)
        let earlierTime = EarlierOffset.minutes30.targetTimestamp(from: currentNow.value)
        let mondayWine = try service.log(preset: smallWinePreset, at: earlierTime, source: .watch)
        #expect(mondayWine.timestamp == earlierTime)

        let loggedEn = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(loggedEn.isDrinkingToday)
        #expect(loggedEn.headerText == "Today: 1.5 HU")
        #expect(loggedEn.todayDrinks.count == 2)
        // mondayBeer has later timestamp (20:00) than mondayWine (19:30), so mondayBeer is most recent
        #expect(loggedEn.mostRecentTodayDrinkId == mondayBeer.id)

        let loggedDe = try WatchLoggerSnapshot.load(from: service, locale: Self.germanLocale)
        #expect(loggedDe.headerText == "Heute: 1,5 HU")

        // Undo the most recent drink (mondayBeer) -> Today: 0.5 HU
        try service.undo(mondayBeer)
        let afterUndo = try WatchLoggerSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(afterUndo.todayDrinks.count == 1)
        #expect(afterUndo.headerText == "Today: 0.5 HU")
        #expect(afterUndo.mostRecentTodayDrinkId == mondayWine.id)
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
