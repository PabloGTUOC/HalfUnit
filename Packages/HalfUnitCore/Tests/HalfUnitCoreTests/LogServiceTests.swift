import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("LogService Tests")
@MainActor
struct LogServiceTests {
    private static let berlin = TimeZone(identifier: "Europe/Berlin")!
    private static let newYork = TimeZone(identifier: "America/New_York")!

    private static func dec(_ string: String) -> Decimal {
        guard let value = Decimal(string: string) else {
            preconditionFailure("Invalid decimal string: \(string)")
        }
        return value
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid date components: \(components)")
        }
        return date
    }

    private final class MutableClock: @unchecked Sendable {
        var currentNow: Date
        var currentTimeZone: TimeZone

        init(now: Date, timeZone: TimeZone) {
            self.currentNow = now
            self.currentTimeZone = timeZone
        }
    }

    private struct TestHarness {
        let container: ModelContainer
        let context: ModelContext
        let clock: MutableClock
        let service: LogService
    }

    private func makeTestHarness(
        now: Date = LogServiceTests.makeDate(
            year: 2026,
            month: 10,
            day: 22,
            hour: 18,
            minute: 0,
            timeZone: LogServiceTests.berlin
        ),
        timeZone: TimeZone = LogServiceTests.berlin
    ) throws -> TestHarness {
        let container = try ModelContainerFactory.make(
            storeURL: nil,
            cloudKitContainerIdentifier: nil,
            inMemory: true
        )
        let context = container.mainContext
        let clock = MutableClock(now: now, timeZone: timeZone)
        let service = LogService(
            context: context,
            now: { clock.currentNow },
            timeZone: { clock.currentTimeZone }
        )
        return TestHarness(container: container, context: context, clock: clock, service: service)
    }

    @Test("settings() creates default once with firstUseDayKey = today, and returns newest updatedAt on duplicates")
    func settingsCreationAndDuplicateResolution() throws {
        let start = Self.makeDate(year: 2026, month: 10, day: 22, hour: 0, minute: 30, timeZone: Self.berlin)
        // 2026-10-22 00:30 Berlin with boundary 7 is logical day 2026-10-21
        let harness = try makeTestHarness(now: start, timeZone: Self.berlin)
        let context = harness.context
        let service = harness.service

        let first = try service.settings()
        #expect(first.dayBoundaryHour == 7)
        #expect(first.displayUnit == .hu)
        #expect(first.firstUseDay == LogicalDay(year: 2026, month: 10, day: 21))
        #expect(first.firstUseDayKey == 20_261_021)

        let secondCall = try service.settings()
        let allAfterSecondCall = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(allAfterSecondCall.count == 1)
        #expect(secondCall.firstUseDayKey == first.firstUseDayKey)

        // Simulate CloudKit duplicate with newer updatedAt
        let newerDate = start.addingTimeInterval(3600)
        let duplicate = AppSettings(
            dayBoundaryHour: 5,
            displayUnitRaw: DisplayUnit.grams.rawValue,
            firstUseDayKey: 20_261_001,
            updatedAt: newerDate
        )
        context.insert(duplicate)
        try context.save()

        let resolved = try service.settings()
        #expect(resolved.dayBoundaryHour == 5)
        #expect(resolved.displayUnit == .grams)
        #expect(resolved.firstUseDayKey == 20_261_001)
        // Duplicates are not deleted
        #expect(try context.fetch(FetchDescriptor<AppSettings>()).count == 2)
    }

    @Test("seedDefaultPresetsIfNeeded is idempotent and presets() deduplicates by key and filters hidden")
    func presetsSeedingDeduplicationAndFiltering() throws {
        let start = Self.makeDate(year: 2026, month: 10, day: 22, hour: 12, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: start, timeZone: Self.berlin)
        let context = harness.context
        let service = harness.service

        try service.seedDefaultPresetsIfNeeded()
        try service.seedDefaultPresetsIfNeeded()

        let allStored = try context.fetch(FetchDescriptor<Preset>())
        #expect(allStored.count == 6)

        let visiblePresets = try service.presets()
        #expect(visiblePresets.count == 6)
        #expect(visiblePresets.map(\.key) == ["smallBeer", "smallWine", "beer", "wineGlass", "shot", "longDrink"])

        // Insert a newer duplicate for "beer" with custom name and a hidden preset for "shot"
        let newerBeer = Preset(
            key: "beer",
            name: "Helles 0.5l",
            symbolName: "mug.fill",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            sortOrder: 2,
            isHidden: false,
            updatedAt: start.addingTimeInterval(100)
        )
        context.insert(newerBeer)

        if let shotPreset = visiblePresets.first(where: { $0.key == "shot" }) {
            shotPreset.isHidden = true
            shotPreset.updatedAt = start.addingTimeInterval(50)
        }

        // Insert two user presets with nil key (never deduplicated against each other)
        let customA = Preset(
            key: nil,
            name: "Aperol Spritz",
            symbolName: "wineglass",
            huHalfSteps: 2,
            volumeMl: 200,
            abvTenths: 110,
            sortOrder: 10,
            isHidden: false,
            updatedAt: start
        )
        let customB = Preset(
            key: nil,
            name: "Mass 1l",
            symbolName: "mug.fill",
            huHalfSteps: 4,
            volumeMl: 1000,
            abvTenths: 50,
            sortOrder: 10,
            isHidden: false,
            updatedAt: start
        )
        context.insert(customA)
        context.insert(customB)
        try context.save()

        let afterChanges = try service.presets()
        // 6 default - 1 hidden ("shot") + 2 user presets = 7
        #expect(afterChanges.count == 7)
        #expect(!afterChanges.contains(where: { $0.key == "shot" }))
        #expect(afterChanges.first(where: { $0.key == "beer" })?.name == "Helles 0.5l")
        #expect(afterChanges.suffix(2).map(\.name) == ["Aperol Spritz", "Mass 1l"])
    }

    @Test("log() respects 07:00 boundary at 01:30, spring/autumn DST weeks, time-zone switch, and earlier timestamp")
    func logBoundaryDSTTimeZoneAndEarlierTimestamp() throws {
        let initialNow = Self.makeDate(year: 2026, month: 6, day: 15, hour: 1, minute: 30, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: initialNow, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service
        try service.seedDefaultPresetsIfNeeded()
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))

        // 1. 01:30 in Berlin (boundary 7) -> previous day (2026-06-14)
        let drinkAt0130 = try service.log(preset: beer, source: .watch)
        #expect(drinkAt0130.logicalDayKey == 20_260_614)
        #expect(drinkAt0130.logicalDay == LogicalDay(year: 2026, month: 6, day: 14))
        #expect(drinkAt0130.hu == Decimal(1))
        #expect(drinkAt0130.grams == Decimal(20))
        #expect(drinkAt0130.healthSyncVersion == 0)

        // 2. 07:00 in Berlin -> same day (2026-06-15)
        clock.currentNow = Self.makeDate(year: 2026, month: 6, day: 15, hour: 7, minute: 0, timeZone: Self.berlin)
        let drinkAt0700 = try service.log(preset: beer, source: .phone)
        #expect(drinkAt0700.logicalDayKey == 20_260_615)

        // 3. Spring DST transition in Berlin: 2026-03-29 01:30 -> 2026-03-28
        clock.currentNow = Self.makeDate(year: 2026, month: 3, day: 29, hour: 1, minute: 30, timeZone: Self.berlin)
        let springDSTDrink = try service.log(preset: beer, source: .watch)
        #expect(springDSTDrink.logicalDayKey == 20_260_328)

        // 4. Autumn DST transition in Berlin: 2026-10-25 01:30 -> 2026-10-24
        clock.currentNow = Self.makeDate(year: 2026, month: 10, day: 25, hour: 1, minute: 30, timeZone: Self.berlin)
        let autumnDSTDrink = try service.log(preset: beer, source: .watch)
        #expect(autumnDSTDrink.logicalDayKey == 20_261_024)

        // 5. Log in America/New_York, then switch clock time zone to Europe/Berlin
        // 2026-07-04 23:00 in New York (EDT) is 2026-07-05 05:00 in Berlin (CEST), logical day in NY is 2026-07-04
        clock.currentTimeZone = Self.newYork
        clock.currentNow = Self.makeDate(year: 2026, month: 7, day: 4, hour: 23, minute: 0, timeZone: Self.newYork)
        let nyDrink = try service.log(preset: beer, source: .phone)
        #expect(nyDrink.timeZoneIdentifier == "America/New_York")
        #expect(nyDrink.logicalDayKey == 20_260_704)

        // Switch device time zone back to Berlin; stored NY drink keeps its NY logical day
        clock.currentTimeZone = Self.berlin
        clock.currentNow = Self.makeDate(year: 2026, month: 7, day: 6, hour: 12, minute: 0, timeZone: Self.berlin)
        #expect(nyDrink.logicalDay == LogicalDay(year: 2026, month: 7, day: 4))
        #expect(nyDrink.timeZone == Self.newYork)

        // 6. Earlier-time log ("log at a different time")
        let earlierTime = Self.makeDate(year: 2026, month: 7, day: 5, hour: 21, minute: 15, timeZone: Self.berlin)
        let earlierDrink = try service.log(preset: beer, at: earlierTime, source: .phone)
        #expect(earlierDrink.timestamp == earlierTime)
        #expect(earlierDrink.logicalDayKey == 20_260_705)
        #expect(earlierDrink.createdAt == clock.currentNow)
    }

    @Test("logCustom validates HU and uses estimatedGrams when volume or ABV is omitted")
    func logCustomValidationAndEstimatedGrams() throws {
        let harness = try makeTestHarness()
        let service = harness.service

        #expect(throws: LogServiceError.invalidHU) {
            try service.logCustom(name: "Zero", hu: Decimal(0), source: .phone)
        }
        #expect(throws: LogServiceError.invalidHU) {
            try service.logCustom(name: "Quarter", hu: Self.dec("0.25"), source: .phone)
        }
        #expect(throws: LogServiceError.invalidHU) {
            try service.logCustom(name: "Negative", hu: Self.dec("-1"), source: .phone)
        }

        // Without volume/ABV -> estimatedGrams (1.5 HU * 20 = 30 g)
        let estimated = try service.logCustom(
            name: "House Cocktail",
            hu: Self.dec("1.5"),
            volumeMl: nil,
            abvPercent: nil,
            at: nil,
            source: .phone
        )
        #expect(estimated.hu == Self.dec("1.5"))
        #expect(estimated.grams == Decimal(30))
        #expect(estimated.centigrams == 3000)

        // With volume and ABV -> exact grams (200 ml @ 12% = 19.2 g)
        let exact = try service.logCustom(
            name: "Custom Wine",
            hu: Decimal(1),
            volumeMl: 200,
            abvPercent: Decimal(12),
            at: nil,
            source: .phone
        )
        #expect(exact.grams == Self.dec("19.2"))
        #expect(exact.centigrams == 1920)
    }

    @Test(
        "edit() bumps healthSyncVersion & updatedAt, recomputes logicalDay in drink's zone, clears note, and rejects deleted drinks"
    )
    func editBehavior() throws {
        let nyTime = Self.makeDate(year: 2026, month: 8, day: 10, hour: 22, minute: 0, timeZone: Self.newYork)
        let harness = try makeTestHarness(now: nyTime, timeZone: Self.newYork)
        let clock = harness.clock
        let service = harness.service

        let drink = try service.logCustom(
            name: "IPA",
            hu: Decimal(1),
            volumeMl: 500,
            abvPercent: Self.dec("4.9"),
            at: nil,
            source: .phone
        )
        #expect(drink.grams == Self.dec("19.6"))
        #expect(drink.healthSyncVersion == 0)
        #expect(drink.logicalDayKey == 20_260_810)

        // Move device to Berlin and advance time
        clock.currentTimeZone = Self.berlin
        let editTime1 = nyTime.addingTimeInterval(600)
        clock.currentNow = editTime1

        // Set a note and change timestamp to 2026-08-10 02:00 New York time (which is 08:00 in Berlin!)
        // Because logicalDayKey must be recomputed in the DRINK'S stored time zone (America/New_York),
        // 02:00 NY (< 07:00 boundary) must map to 2026-08-09, NOT 2026-08-10.
        let newTimestampInNY = Self.makeDate(year: 2026, month: 8, day: 10, hour: 2, minute: 0, timeZone: Self.newYork)
        try service.edit(
            drink,
            DrinkEdit(
                timestamp: newTimestampInNY,
                note: .set("Late night pint")
            )
        )
        #expect(drink.healthSyncVersion == 1)
        #expect(drink.updatedAt == editTime1)
        #expect(drink.note == "Late night pint")
        #expect(drink.logicalDayKey == 20_260_809)

        // Clear the note and clear volumeMl so grams falls back to estimatedGrams(hu: 1.5) = 30g
        let editTime2 = editTime1.addingTimeInterval(600)
        clock.currentNow = editTime2
        try service.edit(
            drink,
            DrinkEdit(
                hu: Self.dec("1.5"),
                volumeMl: .clear,
                note: .clear
            )
        )
        #expect(drink.healthSyncVersion == 2)
        #expect(drink.updatedAt == editTime2)
        #expect(drink.note == nil)
        #expect(drink.volumeMl == nil)
        #expect(drink.hu == Self.dec("1.5"))
        #expect(drink.grams == Decimal(30))

        // Invalid HU on edit throws
        #expect(throws: LogServiceError.invalidHU) {
            try service.edit(drink, DrinkEdit(hu: Self.dec("0.3")))
        }

        // Delete and verify editing throws .drinkIsDeleted
        try service.delete(drink)
        #expect(throws: LogServiceError.drinkIsDeleted) {
            try service.edit(drink, DrinkEdit(name: "Should Fail"))
        }
    }

    @Test("edit() with preset snapshots preset fields and applies explicit overrides on top")
    func editPresetAndOverrides() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 19, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service
        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))
        let shot = try #require(presets.first(where: { $0.key == "shot" }))

        let drink = try service.log(preset: beer, source: .phone)
        #expect(drink.presetId == beer.id)
        #expect(drink.name == "beer")
        #expect(drink.hu == Decimal(1))
        #expect(drink.volumeMl == 500)
        #expect(drink.abvPercent == Decimal(5))
        #expect(drink.grams == Decimal(20))
        #expect(drink.healthSyncVersion == 0)

        // 1. Change preset to wineGlass without overrides
        let t1 = t0.addingTimeInterval(60)
        clock.currentNow = t1
        try service.edit(drink, DrinkEdit(preset: wine))
        #expect(drink.presetId == wine.id)
        #expect(drink.name == "wineGlass")
        #expect(drink.hu == Decimal(1))
        #expect(drink.volumeMl == 200)
        #expect(drink.abvPercent == Decimal(12))
        #expect(drink.grams == Self.dec("19.2"))
        #expect(drink.healthSyncVersion == 1)
        #expect(drink.updatedAt == t1)

        // 2. Change preset to shot AND pass explicit HU and volumeMl overrides in the same edit
        let t2 = t1.addingTimeInterval(60)
        clock.currentNow = t2
        try service.edit(
            drink,
            DrinkEdit(
                preset: shot,
                hu: Self.dec("1.5"),
                volumeMl: .set(60)
            )
        )
        #expect(drink.presetId == shot.id)
        #expect(drink.name == "shot")
        #expect(drink.hu == Self.dec("1.5"))
        #expect(drink.volumeMl == 60)
        #expect(drink.abvPercent == Decimal(40))
        // 60 ml * 40% * 0.8 = 19.2 g
        #expect(drink.grams == Self.dec("19.2"))
        #expect(drink.healthSyncVersion == 2)
        #expect(drink.updatedAt == t2)
    }

    @Test("delete and undo set tombstone and exclude drink from drinks() and snapshots() unless includeDeleted is true")
    func deleteAndUndoFiltering() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 19, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service
        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))

        let d1 = try service.log(preset: beer, source: .phone)
        clock.currentNow = t0.addingTimeInterval(60)
        let d2 = try service.log(preset: wine, source: .watch)

        #expect(try service.drinks().map(\.id) == [d2.id, d1.id])

        let deleteTime = t0.addingTimeInterval(120)
        clock.currentNow = deleteTime
        try service.undo(d2)

        #expect(d2.deletedAt == deleteTime)
        #expect(d2.updatedAt == deleteTime)
        #expect(try service.drinks().map(\.id) == [d1.id])
        #expect(try service.drinks(includeDeleted: true).map(\.id) == [d2.id, d1.id])

        let snaps = try service.snapshots()
        #expect(snaps.count == 1)
        #expect(snaps.first?.id == d1.id)
        #expect(snaps.first?.presetKey == "beer")
    }

    @Test("purgeTombstones keeps 29-day-old tombstone, purges 31-day-old tombstone, and leaves live drinks untouched")
    func purgeTombstonesRetention() throws {
        let baseNow = Self.makeDate(year: 2026, month: 10, day: 22, hour: 12, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: baseNow, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service

        // Log 3 drinks 40 days ago
        clock.currentNow = baseNow.addingTimeInterval(-40 * 86_400)
        let oldDeleted = try service.logCustom(name: "Old Deleted", hu: Decimal(1), source: .phone)
        let recentDeleted = try service.logCustom(name: "Recent Deleted", hu: Decimal(1), source: .phone)
        _ = try service.logCustom(name: "Live Drink", hu: Decimal(1), source: .phone)

        // Delete oldDeleted 31 days before baseNow
        clock.currentNow = baseNow.addingTimeInterval(-31 * 86_400)
        try service.delete(oldDeleted)

        // Delete recentDeleted 29 days before baseNow
        clock.currentNow = baseNow.addingTimeInterval(-29 * 86_400)
        try service.delete(recentDeleted)

        // Purge at baseNow
        clock.currentNow = baseNow
        let purgedCount = try service.purgeTombstones()
        #expect(purgedCount == 1)

        let remainingAll = try service.drinks(includeDeleted: true)
        #expect(remainingAll.count == 2)
        #expect(Set(remainingAll.map(\.name)) == ["Recent Deleted", "Live Drink"])
        #expect(try service.drinks(includeDeleted: false).map(\.name) == ["Live Drink"])
    }

    @Test("snapshots() feed StatsEngine: logging Friday 22:00 and Saturday 01:30 counts as 1 drinking day")
    func snapshotsIntegrationWithStatsEngine() throws {
        let fri2200 = Self.makeDate(year: 2026, month: 10, day: 16, hour: 22, minute: 0, timeZone: Self.berlin)
        let sat0130 = Self.makeDate(year: 2026, month: 10, day: 17, hour: 1, minute: 30, timeZone: Self.berlin)
        let sun1200 = Self.makeDate(year: 2026, month: 10, day: 18, hour: 12, minute: 0, timeZone: Self.berlin)

        let harness = try makeTestHarness(now: fri2200, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service
        try service.seedDefaultPresetsIfNeeded()
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))
        let shot = try #require(try service.presets().first(where: { $0.key == "shot" }))

        try service.log(preset: beer, source: .phone)

        clock.currentNow = sat0130
        try service.log(preset: shot, source: .watch)

        clock.currentNow = sun1200
        let settings = try service.settings()
        let today = try service.today()
        let snapshots = try service.snapshots()

        #expect(snapshots.count == 2)
        #expect(snapshots.allSatisfy { $0.logicalDay == LogicalDay(year: 2026, month: 10, day: 16) })

        let engine = StatsEngine(
            drinks: snapshots,
            firstUseDay: settings.firstUseDay,
            today: today
        )
        let periodStats = engine.stats(for: .last7Days)
        #expect(periodStats.drinkingDays == 1)
        #expect(periodStats.totalHU == Decimal(2))
        #expect(periodStats.totalGrams == Self.dec("32.8"))

        let streaks = engine.streaks()
        #expect(streaks.lastDrinkingDay == LogicalDay(year: 2026, month: 10, day: 16))
        #expect(streaks.currentStreakDays == 2)
    }

    @Test("Preset management: add, update, hide/unhide, reorder, HU validation, and past drinks unchanged")
    func presetManagementAndPastDrinksPreservation() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 12, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service

        try service.seedDefaultPresetsIfNeeded()
        let initialPresets = try service.presets()
        let beer = try #require(initialPresets.first(where: { $0.key == "beer" }))

        // Log a drink before editing the preset
        let pastDrink = try service.log(preset: beer, source: .phone)
        #expect(pastDrink.name == "beer")
        #expect(pastDrink.hu == Decimal(1))
        #expect(pastDrink.volumeMl == 500)
        #expect(pastDrink.abvPercent == Decimal(5))
        #expect(pastDrink.grams == Decimal(20))

        // Invalid HU rejected on addPreset and updatePreset
        #expect(throws: LogServiceError.invalidHU) {
            _ = try service.addPreset(
                name: "Bad",
                symbolName: "mug",
                hu: Self.dec("0.25"),
                volumeMl: 250,
                abvPercent: Decimal(5)
            )
        }
        #expect(throws: LogServiceError.invalidHU) {
            try service.updatePreset(
                beer,
                name: "Beer",
                symbolName: "mug.fill",
                hu: Decimal(0),
                volumeMl: 500,
                abvPercent: Decimal(5)
            )
        }

        // Update default preset: keeps its key, bumps updatedAt, leaves past drink untouched
        let t1 = t0.addingTimeInterval(60)
        clock.currentNow = t1
        try service.updatePreset(
            beer,
            name: "Helles",
            symbolName: "mug",
            hu: Self.dec("1.5"),
            volumeMl: 500,
            abvPercent: Self.dec("5.2")
        )
        #expect(beer.key == "beer")
        #expect(beer.name == "Helles")
        #expect(beer.name != beer.key)
        #expect(beer.symbolName == "mug")
        #expect(beer.hu == Self.dec("1.5"))
        #expect(beer.volumeMl == 500)
        #expect(beer.abvPercent == Self.dec("5.2"))
        #expect(beer.grams == Self.dec("20.8"))
        #expect(beer.updatedAt == t1)

        // Past drink snapshot is completely unchanged
        #expect(pastDrink.name == "beer")
        #expect(pastDrink.hu == Decimal(1))
        #expect(pastDrink.volumeMl == 500)
        #expect(pastDrink.abvPercent == Decimal(5))
        #expect(pastDrink.grams == Decimal(20))

        // Add custom preset
        let t2 = t1.addingTimeInterval(60)
        clock.currentNow = t2
        let custom = try service.addPreset(
            name: "Mass 1l",
            symbolName: "mug.fill",
            hu: Decimal(2),
            volumeMl: 1000,
            abvPercent: Decimal(5)
        )
        #expect(custom.key == nil)
        #expect(custom.name == "Mass 1l")
        #expect(custom.hu == Decimal(2))
        #expect(custom.grams == Decimal(40))
        #expect(custom.sortOrder == 6)
        #expect(custom.updatedAt == t2)

        // Hide and unhide preset
        let t3 = t2.addingTimeInterval(60)
        clock.currentNow = t3
        try service.setPresetHidden(beer, true)
        #expect(beer.isHidden)
        #expect(beer.updatedAt == t3)
        #expect(!((try service.presets()).contains(where: { $0.id == beer.id })))
        #expect((try service.presets(includeHidden: true)).contains(where: { $0.id == beer.id }))

        let t4 = t3.addingTimeInterval(60)
        clock.currentNow = t4
        try service.setPresetHidden(beer, false)
        #expect(!beer.isHidden)
        #expect(beer.updatedAt == t4)
        #expect((try service.presets()).contains(where: { $0.id == beer.id }))

        // Move custom preset from last (index 6) to first (offset 0)
        let t5 = t4.addingTimeInterval(60)
        clock.currentNow = t5
        try service.movePresets(fromOffsets: IndexSet(integer: 6), toOffset: 0)
        let reordered = try service.presets(includeHidden: true)
        #expect(reordered.first?.id == custom.id)
        #expect(reordered.map(\.sortOrder) == Array(0..<7))
        #expect(reordered.allSatisfy { $0.updatedAt == t5 })
    }

    @Test(
        "changeDayBoundary recomputes logicalDayKey in each drink's time zone, bumps updatedAt only on changed drinks, and preserves healthSyncVersion"
    )
    func changeDayBoundaryWith0130DSTAndTimeZone() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 12, minute: 0, timeZone: Self.berlin)
        let harness = try makeTestHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service
        try service.seedDefaultPresetsIfNeeded()
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))

        // 1. 01:30 drink in Berlin on 2026-10-22 (with default boundary 07:00 -> logical day 2026-10-21)
        let t0130 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 1, minute: 30, timeZone: Self.berlin)
        clock.currentNow = t0130
        let drink0130 = try service.log(preset: beer, at: t0130, source: .phone)
        drink0130.healthSyncedVersion = 0
        #expect(drink0130.logicalDay == LogicalDay(year: 2026, month: 10, day: 21))

        // 2. Evening drink at 20:00 on 2026-10-22 (logical day 2026-10-22 under both 07:00 and 01:00 boundaries)
        let t2000 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 0, timeZone: Self.berlin)
        clock.currentNow = t2000
        let drink2000 = try service.log(preset: beer, at: t2000, source: .phone)
        drink2000.healthSyncedVersion = 0
        #expect(drink2000.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))

        // 3. Spring DST drink in Berlin: Sunday 2026-03-29 01:30 -> 2026-03-28 at boundary 07, moves to 2026-03-29 at boundary 01
        let tSpringDST = Self.makeDate(year: 2026, month: 3, day: 29, hour: 1, minute: 30, timeZone: Self.berlin)
        clock.currentNow = tSpringDST
        let drinkSpringDST = try service.log(preset: beer, at: tSpringDST, source: .watch)
        #expect(drinkSpringDST.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))

        // 4. Time-zone-stored drink in America/New_York:
        // Logged at 2026-07-05 03:30 New York time (which is 09:30 in Berlin!).
        // With boundary 07:00, in New York 03:30 < 07:00 -> logical day 2026-07-04.
        // When boundary changes to 05:00, in New York 03:30 < 05:00 -> STILL 2026-07-04.
        // When boundary changes to 01:00, in New York 03:30 >= 01:00 -> moves to 2026-07-05.
        clock.currentTimeZone = Self.newYork
        let tNY0330 = Self.makeDate(year: 2026, month: 7, day: 5, hour: 3, minute: 30, timeZone: Self.newYork)
        clock.currentNow = tNY0330
        let drinkNY = try service.log(preset: beer, at: tNY0330, source: .phone)
        #expect(drinkNY.timeZoneIdentifier == "America/New_York")
        #expect(drinkNY.logicalDay == LogicalDay(year: 2026, month: 7, day: 4))

        // Switch device back to Berlin
        clock.currentTimeZone = Self.berlin
        let boundaryChangeTime1 = Self.makeDate(
            year: 2026, month: 10, day: 23, hour: 10, minute: 0, timeZone: Self.berlin)
        clock.currentNow = boundaryChangeTime1

        // Invalid boundary hours throw
        #expect(throws: LogServiceError.invalidDayBoundaryHour) {
            try service.changeDayBoundary(to: -1)
        }
        #expect(throws: LogServiceError.invalidDayBoundaryHour) {
            try service.changeDayBoundary(to: 24)
        }

        // First change boundary from 07 -> 05:
        // All 01:30 and 03:30 NY drinks remain before 05:00 in their own zones, so NO drink changes!
        try service.changeDayBoundary(to: 5)
        #expect(try service.settings().dayBoundaryHour == 5)
        #expect(try service.settings().updatedAt == boundaryChangeTime1)
        #expect(drink0130.updatedAt == t0130)
        #expect(drink2000.updatedAt == t2000)
        #expect(drinkSpringDST.updatedAt == tSpringDST)
        #expect(drinkNY.updatedAt == tNY0330)

        // Now change boundary from 05 -> 01:
        // drink0130, drinkSpringDST, and drinkNY move forward by 1 day; drink2000 is unchanged!
        let boundaryChangeTime2 = boundaryChangeTime1.addingTimeInterval(300)
        clock.currentNow = boundaryChangeTime2
        try service.changeDayBoundary(to: 1)

        #expect(try service.settings().dayBoundaryHour == 1)
        #expect(try service.settings().updatedAt == boundaryChangeTime2)

        #expect(drink0130.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))
        #expect(drink0130.updatedAt == boundaryChangeTime2)
        #expect(drink0130.healthSyncVersion == 0)
        #expect(drink0130.healthSyncedVersion == 0)

        #expect(drinkSpringDST.logicalDay == LogicalDay(year: 2026, month: 3, day: 29))
        #expect(drinkSpringDST.updatedAt == boundaryChangeTime2)
        #expect(drinkSpringDST.healthSyncVersion == 0)

        #expect(drinkNY.logicalDay == LogicalDay(year: 2026, month: 7, day: 5))
        #expect(drinkNY.updatedAt == boundaryChangeTime2)
        #expect(drinkNY.healthSyncVersion == 0)

        // Unchanged evening drink did NOT bump updatedAt or healthSyncVersion
        #expect(drink2000.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))
        #expect(drink2000.updatedAt == t2000)
        #expect(drink2000.healthSyncVersion == 0)
        #expect(drink2000.healthSyncedVersion == 0)
    }
}
