import Foundation
import HalfUnitCore
import SwiftData
import Testing
import UIKit

@testable import HalfUnit

@Suite("HalfUnit iOS App Layer Tests")
struct HalfUnitAppTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")
    private static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!
    private static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    @Test("Preset keys map to catalog keys, localized names, and valid SF Symbols")
    func presetPresentationMappings() {
        let expectedCatalogKeys: [(String, String, String, String, String)] = [
            ("smallBeer", "preset.smallBeer", "Small beer", "Kleines Bier", "mug"),
            ("smallWine", "preset.smallWine", "Small wine", "Kleiner Wein", "wineglass"),
            ("beer", "preset.beer", "Beer", "Bier", "mug.fill"),
            ("wineGlass", "preset.wineGlass", "Wine glass", "Glas Wein", "wineglass.fill"),
            ("shot", "preset.shot", "Shot", "Schnaps", "cup.and.saucer"),
            (
                "longDrink",
                "preset.longDrink",
                "Long drink",
                "Longdrink",
                "takeoutbag.and.cup.and.straw"
            ),
        ]

        for (key, catalogKey, enName, deName, symbol) in expectedCatalogKeys {
            #expect(PresetPresentation.catalogKey(for: key) == catalogKey)
            #expect(
                PresetPresentation.localizedName(
                    presetKey: key,
                    fallbackName: key,
                    locale: Self.englishLocale
                ) == enName
            )
            #expect(
                PresetPresentation.localizedName(
                    presetKey: key,
                    fallbackName: key,
                    locale: Self.germanLocale
                ) == deName
            )
            let resolvedSymbol = PresetPresentation.symbolName(
                presetKey: key,
                fallbackSymbol: "questionmark"
            )
            #expect(resolvedSymbol == symbol)
            #expect(UIImage(systemName: resolvedSymbol) != nil)
        }

        #expect(PresetPresentation.catalogKey(for: nil) == nil)
        #expect(
            PresetPresentation.localizedName(
                presetKey: nil,
                fallbackName: "Mass 1L",
                locale: Self.englishLocale
            ) == "Mass 1L"
        )
        #expect(
            PresetPresentation.symbolName(presetKey: nil, fallbackSymbol: "mug.fill") == "mug.fill"
        )
    }

    @Test("Accessibility labels localize preset name and singular or plural units")
    func accessibilityLabels() {
        let beerEn = PresetPresentation.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            hu: Decimal(1),
            locale: Self.englishLocale
        )
        #expect(beerEn == "Log beer, 1 unit")

        let smallBeerEn = PresetPresentation.accessibilityLabel(
            presetKey: "smallBeer",
            fallbackName: "smallBeer",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            locale: Self.englishLocale
        )
        #expect(smallBeerEn == "Log small beer, 0.5 units")

        let beerDe = PresetPresentation.accessibilityLabel(
            presetKey: "beer",
            fallbackName: "beer",
            hu: Decimal(1),
            locale: Self.germanLocale
        )
        #expect(beerDe == "Bier protokollieren, 1 Einheit")

        let smallBeerDe = PresetPresentation.accessibilityLabel(
            presetKey: "smallBeer",
            fallbackName: "smallBeer",
            hu: Decimal(sign: .plus, exponent: -1, significand: 5),
            locale: Self.germanLocale
        )
        #expect(smallBeerDe == "Kleines Bier protokollieren, 0,5 Einheiten")
    }

    @Test("StreakCardModel formats empty state, multi-day streak, and drinking today")
    func streakCardModelFormatting() {
        let emptySummary = StreakSummary(
            lastDrinkingDay: nil,
            lastDrink: nil,
            isDrinkingToday: false,
            currentStreakDays: 1,
            previousStreakDays: nil,
            longestStreakEver: 1,
            longestStreakThisYear: 1
        )
        let emptyCardEn = StreakCardModel(summary: emptySummary, locale: Self.englishLocale)
        #expect(emptyCardEn.isEmptyState)
        #expect(!emptyCardEn.isDrinkingToday)
        #expect(emptyCardEn.headline == "1 day without alcohol")
        #expect(emptyCardEn.subtitle == "No drinks logged yet. Your counter starts now.")

        let emptyCardDe = StreakCardModel(summary: emptySummary, locale: Self.germanLocale)
        #expect(emptyCardDe.headline == "1 Tag ohne Alkohol")
        #expect(
            emptyCardDe.subtitle == "Noch keine Getränke protokolliert. Dein Zähler startet jetzt."
        )

        let saturdayDay = LogicalDay(year: 2026, month: 9, day: 26)
        let lastDrink = DrinkSnapshot(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_758_916_800),
            logicalDay: saturdayDay,
            presetKey: "beer",
            name: "beer",
            hu: Decimal(1),
            grams: Decimal(20)
        )
        let streakSummary = StreakSummary(
            lastDrinkingDay: saturdayDay,
            lastDrink: lastDrink,
            isDrinkingToday: false,
            currentStreakDays: 2,
            previousStreakDays: nil,
            longestStreakEver: 5,
            longestStreakThisYear: 5
        )
        let activeCardEn = StreakCardModel(summary: streakSummary, locale: Self.englishLocale)
        #expect(activeCardEn.headline == "2 days without alcohol")
        #expect(activeCardEn.previousStreakText == nil)
        #expect(activeCardEn.subtitle.contains("Last drink:"))
        #expect(activeCardEn.subtitle.contains("Beer"))

        let todayDrinkSummary = StreakSummary(
            lastDrinkingDay: LogicalDay(year: 2026, month: 9, day: 28),
            lastDrink: lastDrink,
            isDrinkingToday: true,
            currentStreakDays: 0,
            previousStreakDays: 4,
            longestStreakEver: 4,
            longestStreakThisYear: 4
        )
        let todayCardEn = StreakCardModel(summary: todayDrinkSummary, locale: Self.englishLocale)
        #expect(todayCardEn.isDrinkingToday)
        #expect(todayCardEn.headline == "Today")
        #expect(todayCardEn.previousStreakText == "Previous streak: 4 days")
    }

    @Test("TodayScreenSnapshot handles 07:00 boundary, 01:30 drink, DST week, time-zone change, and undo")
    @MainActor
    func todayScreenSnapshotWithInMemoryStore() throws {
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
        #expect(presets.count == 6)

        let beerPreset = try #require(presets.first(where: { $0.key == "beer" }))
        let winePreset = try #require(presets.first(where: { $0.key == "wineGlass" }))

        // Log a drink at 01:30 on Sunday 2026-03-29 (DST spring-forward day in Europe/Berlin).
        // Because 01:30 is before the 07:00 boundary, it belongs to Saturday 2026-03-28.
        currentNow.setValue(Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone))
        let lateNightDrink = try service.log(preset: beerPreset, source: .phone)
        #expect(lateNightDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))

        // At 06:59 on Sunday 2026-03-29, logical today is still 2026-03-28.
        currentNow.setValue(Self.makeDate(2026, 3, 29, 6, 59, in: Self.berlinTimeZone))
        let beforeBoundary = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(beforeBoundary.streakCard.isDrinkingToday)
        #expect(beforeBoundary.todayDrinks.count == 1)
        #expect(beforeBoundary.todayTotalHU == Decimal(1))

        // At 07:00 on Sunday 2026-03-29 (after DST transition), logical today advances to 2026-03-29.
        currentNow.setValue(Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        let afterBoundary = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(!afterBoundary.streakCard.isDrinkingToday)
        #expect(afterBoundary.streakCard.headline == "1 day without alcohol")
        #expect(afterBoundary.todayDrinks.isEmpty)

        // Advance to Monday 2026-03-30 in a different time zone (Asia/Tokyo).
        // Past drink stays on 2026-03-28; Saturday -> Monday streak is 2 days.
        currentZone.setValue(Self.tokyoTimeZone)
        currentNow.setValue(Self.makeDate(2026, 3, 30, 12, 0, in: Self.tokyoTimeZone))
        let mondaySnapshot = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(mondaySnapshot.streakCard.headline == "2 days without alcohol")

        // Log two drinks on Monday and undo one.
        _ = try service.log(preset: beerPreset, source: .phone)
        let secondDrink = try service.log(preset: winePreset, source: .phone)
        let twoDrinksSnapshot = try TodayScreenSnapshot.load(
            from: service,
            locale: Self.englishLocale
        )
        #expect(twoDrinksSnapshot.todayDrinks.count == 2)
        #expect(twoDrinksSnapshot.todayTotalHU == Decimal(2))
        #expect(twoDrinksSnapshot.todayTotalText == "Total: 2 HU")

        try service.undo(secondDrink)
        let afterUndoSnapshot = try TodayScreenSnapshot.load(
            from: service,
            locale: Self.englishLocale
        )
        #expect(afterUndoSnapshot.todayDrinks.count == 1)
        #expect(afterUndoSnapshot.todayTotalHU == Decimal(1))
        #expect(afterUndoSnapshot.todayTotalText == "Total: 1 HU")
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
