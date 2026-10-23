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
    private static let newYorkTimeZone = TimeZone(identifier: "America/New_York")!

    @Test("SharedStore.shared and IntentStoreProvider.shared return the identical process-wide ModelContainer")
    func sharedStoreProcessWideSingletonIdentity() {
        let first = SharedStore.shared
        let second = SharedStore.shared
        let coreShared = IntentStoreProvider.shared
        #expect(first === second)
        #expect(first === coreShared)
    }

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

    @Test(
        "DayBoundaryScheduler computes next boundary for 07:00 boundary, 01:30 now, Europe/Berlin DST week, and time-zone change"
    )
    func dayBoundarySchedulerCases() {
        let currentNow = LockIsolated(Self.makeDate(2026, 10, 22, 21, 15, in: Self.berlinTimeZone))
        let currentZone = LockIsolated(Self.berlinTimeZone)
        let scheduler = DayBoundaryScheduler(
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )

        // 1. Standard 07:00 boundary: evening 21:15 -> next morning 07:00, 06:59 -> 07:00, exact 07:00 -> next day 07:00
        let fromEvening = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(fromEvening == Self.makeDate(2026, 10, 23, 7, 0, in: Self.berlinTimeZone))

        currentNow.setValue(Self.makeDate(2026, 10, 23, 6, 59, in: Self.berlinTimeZone))
        let fromJustBefore = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(fromJustBefore == Self.makeDate(2026, 10, 23, 7, 0, in: Self.berlinTimeZone))

        currentNow.setValue(Self.makeDate(2026, 10, 23, 7, 0, in: Self.berlinTimeZone))
        let fromExactBoundary = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(fromExactBoundary == Self.makeDate(2026, 10, 24, 7, 0, in: Self.berlinTimeZone))

        // 2. 01:30 "now": still on logical day 2026-10-22, so next boundary is 2026-10-23 07:00 (5.5 h later)
        let lateNightNow = Self.makeDate(2026, 10, 23, 1, 30, in: Self.berlinTimeZone)
        currentNow.setValue(lateNightNow)
        let fromLateNight = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(fromLateNight == Self.makeDate(2026, 10, 23, 7, 0, in: Self.berlinTimeZone))
        #expect(fromLateNight.timeIntervalSince(lateNightNow) == 5.5 * 3600)

        // 3. Europe/Berlin DST week (spring forward on Sunday 2026-03-29: 02:00 CET -> 03:00 CEST)
        let satMorningBeforeSpringDST = Self.makeDate(2026, 3, 28, 7, 0, in: Self.berlinTimeZone)
        currentNow.setValue(satMorningBeforeSpringDST)
        let sunMorningAfterSpringDST = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(sunMorningAfterSpringDST == Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        // Spring forward removes 1 hour -> 23 hours between Saturday 07:00 CET and Sunday 07:00 CEST
        #expect(sunMorningAfterSpringDST.timeIntervalSince(satMorningBeforeSpringDST) == 23 * 3600)

        let sun0130SpringDST = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        currentNow.setValue(sun0130SpringDST)
        let sunBoundaryFrom0130 = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(sunBoundaryFrom0130 == Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone))
        #expect(sunBoundaryFrom0130.timeIntervalSince(sun0130SpringDST) == 4.5 * 3600)

        // Rescheduling after Sunday 07:00 CEST fires advances to Monday 2026-03-30 07:00 CEST (24 h)
        let monMorningAfterSpringDST = scheduler.nextBoundaryDate(
            after: sunBoundaryFrom0130,
            boundaryHour: 7
        )
        #expect(monMorningAfterSpringDST == Self.makeDate(2026, 3, 30, 7, 0, in: Self.berlinTimeZone))
        #expect(monMorningAfterSpringDST.timeIntervalSince(sunBoundaryFrom0130) == 24 * 3600)

        // Europe/Berlin autumn DST week (fall back on Sunday 2026-10-25: 03:00 CEST -> 02:00 CET)
        let satMorningBeforeAutumnDST = Self.makeDate(2026, 10, 24, 7, 0, in: Self.berlinTimeZone)
        currentNow.setValue(satMorningBeforeAutumnDST)
        let sunMorningAfterAutumnDST = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(sunMorningAfterAutumnDST == Self.makeDate(2026, 10, 25, 7, 0, in: Self.berlinTimeZone))
        // Fall back adds 1 hour -> 25 hours between Saturday 07:00 CEST and Sunday 07:00 CET
        #expect(sunMorningAfterAutumnDST.timeIntervalSince(satMorningBeforeAutumnDST) == 25 * 3600)

        // 4. Time-zone change at the same instant:
        // 2026-03-30 23:30 in Europe/Berlin (21:30 UTC) is 2026-03-31 06:30 in Asia/Tokyo
        // and 2026-03-30 17:30 in America/New_York.
        let sharedInstant = Self.makeDate(2026, 3, 30, 23, 30, in: Self.berlinTimeZone)
        currentNow.setValue(sharedInstant)
        currentZone.setValue(Self.berlinTimeZone)
        #expect(
            scheduler.nextBoundaryDate(boundaryHour: 7)
                == Self.makeDate(2026, 3, 31, 7, 0, in: Self.berlinTimeZone)
        )

        // In Tokyo it is 06:30 on March 31 (still before 07:00 boundary), so next boundary is 30 minutes later at 07:00 Tokyo time.
        currentZone.setValue(Self.tokyoTimeZone)
        let tokyoBoundary = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(tokyoBoundary == Self.makeDate(2026, 3, 31, 7, 0, in: Self.tokyoTimeZone))
        #expect(tokyoBoundary.timeIntervalSince(sharedInstant) == 1800)

        // In New York it is 17:30 on March 30, so next boundary is March 31 07:00 New York time.
        currentZone.setValue(Self.newYorkTimeZone)
        let newYorkBoundary = scheduler.nextBoundaryDate(boundaryHour: 7)
        #expect(newYorkBoundary == Self.makeDate(2026, 3, 31, 7, 0, in: Self.newYorkTimeZone))
    }

    @Test(
        "WidgetTimelinePlan builds timeline entries for now and next boundary (01:30 drink, 07:00 flip, DST week, time-zone change)"
    )
    @MainActor
    func widgetTimelinePlanEntriesAndStreakFlip() throws {
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

        // Log a beer at 01:30 on DST spring-forward Sunday 2026-03-29 (assigned to Saturday 2026-03-28)
        let lateNight = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        currentNow.setValue(lateNight)
        _ = try LogDrinkIntent.performLog(
            preset: PresetEntity(preset: beerPreset),
            source: .widget,
            logService: service,
            locale: Self.englishLocale
        )

        // Build timeline at 01:30 on 2026-03-29:
        // Entry 0 (now = 01:30): drinking today (Saturday), currentStreakDays == 0, todayTotalHU == 1
        // Entry 1 (nextBoundary = 07:00 CEST, 4.5 hours later): flips to Sunday without opening the app -> 1 day without alcohol!
        let planAt0130 = try WidgetTimelinePlan.build(
            from: service,
            now: lateNight,
            timeZone: Self.berlinTimeZone,
            locale: Self.englishLocale
        )
        let expectedSunday0700 = Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone)
        #expect(planAt0130.entries.map(\.date) == [lateNight, expectedSunday0700])
        #expect(planAt0130.reloadAfterDate == expectedSunday0700)
        #expect(planAt0130.entries[0].snapshot.isDrinkingToday)
        #expect(planAt0130.entries[0].snapshot.currentStreakDays == 0)
        #expect(planAt0130.entries[0].snapshot.streakHeadline == "Today")
        #expect(planAt0130.entries[0].snapshot.presetButtons.count == 3)
        #expect(
            planAt0130.entries[0].snapshot.presetButtons.first(where: { $0.entity.key == "beer" })?
                .accessibilityLabel == "Log beer, 1 unit"
        )

        // At 07:00 boundary slice, streak flips to 1 day without alcohol
        #expect(!planAt0130.entries[1].snapshot.isDrinkingToday)
        #expect(planAt0130.entries[1].snapshot.currentStreakDays == 1)
        #expect(planAt0130.entries[1].snapshot.streakHeadline == "1 day without alcohol")
        #expect(planAt0130.entries[1].snapshot.streakAccessibilityLabel == "1 day without alcohol")

        // Advance to Monday 2026-03-30 in Asia/Tokyo:
        // Entry 0 (now = 12:00 JST) has 2 days without alcohol; Entry 1 (Tuesday 07:00 JST) has 3 days without alcohol
        let mondayTokyo = Self.makeDate(2026, 3, 30, 12, 0, in: Self.tokyoTimeZone)
        currentZone.setValue(Self.tokyoTimeZone)
        currentNow.setValue(mondayTokyo)
        let planMondayDe = try WidgetTimelinePlan.build(
            from: service,
            now: mondayTokyo,
            timeZone: Self.tokyoTimeZone,
            locale: Self.germanLocale
        )
        let expectedTuesdayTokyo0700 = Self.makeDate(2026, 3, 31, 7, 0, in: Self.tokyoTimeZone)
        #expect(planMondayDe.entries.map(\.date) == [mondayTokyo, expectedTuesdayTokyo0700])
        #expect(planMondayDe.entries[0].snapshot.currentStreakDays == 2)
        #expect(planMondayDe.entries[0].snapshot.streakHeadline == "2 Tage ohne Alkohol")
        #expect(planMondayDe.entries[0].snapshot.watchShortDaysText == "2T")
        #expect(planMondayDe.entries[1].snapshot.currentStreakDays == 3)
        #expect(planMondayDe.entries[1].snapshot.streakHeadline == "3 Tage ohne Alkohol")
    }

    @Test(
        "TodayView log/undo reconciles with Health, and launch/foreground maintenance reconciles before purging tombstones"
    )
    @MainActor
    func healthSyncWiringForLogUndoAndTombstonePurgeOrder() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Self.makeDate(2026, 10, 22, 20, 0, in: Self.berlinTimeZone)
        let currentNow = LockIsolated(t0)
        let currentZone = LockIsolated(Self.berlinTimeZone)

        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )
        let client = InMemoryHealthStoreClient()
        let healthSync = HealthSync(
            context: container.mainContext,
            client: client,
            isEnabled: { HalfUnitApp.isHealthSyncEnabled }
        )

        try service.seedDefaultPresetsIfNeeded()
        let beerPreset = try #require(try service.presets().first(where: { $0.key == "beer" }))

        // 1. Log on Today triggers reconcile -> writes sample to Health
        let (loggedDrink, logReconcileTask) = try TodayView.logAndReconcile(
            preset: beerPreset,
            logService: service,
            healthSync: healthSync
        )
        let logStatus = await logReconcileTask.value
        #expect(logStatus == .upToDate)
        #expect(client.savedSamples.count == 1)
        #expect(client.savedSamples.first?.syncIdentifier == loggedDrink.id.uuidString)
        #expect(loggedDrink.healthSyncedVersion == 0)

        // 2. Undo within 5 seconds removes drink from active store AND from Apple Health
        currentNow.setValue(t0.addingTimeInterval(3))
        let undoReconcileTask = try TodayView.undoAndReconcile(
            drink: loggedDrink,
            logService: service,
            healthSync: healthSync
        )
        let undoStatus = await undoReconcileTask.value
        #expect(undoStatus == .upToDate)
        #expect(try service.drinks().isEmpty)
        #expect(client.deletedIdentifiers == [loggedDrink.id.uuidString])
        #expect(loggedDrink.healthSyncedVersion == nil)

        // 3. Launch/foreground maintenance runs reconcile() BEFORE purgeTombstones():
        // Create a drink synced 31 days ago and deleted 31 days ago (before reconcile ran).
        let (oldDrink, oldLogTask) = try TodayView.logAndReconcile(
            preset: beerPreset,
            logService: service,
            healthSync: healthSync
        )
        _ = await oldLogTask.value
        #expect(oldDrink.healthSyncedVersion == 0)

        try service.delete(oldDrink)
        // Advance clock by 31 days so the tombstone is eligible for purgeTombstones().
        currentNow.setValue(t0.addingTimeInterval(31 * 86_400))

        await HalfUnitApp.reconcileAndPurgeTombstones(logService: service, healthSync: healthSync)

        // Because reconcile() ran BEFORE purgeTombstones(), oldDrink was first deleted from Health
        // and then purged from SwiftData.
        #expect(client.deletedIdentifiers.contains(oldDrink.id.uuidString))
        let allRemainingDrinks = try service.drinks(includeDeleted: true)
        #expect(!allRemainingDrinks.contains(where: { $0.id == oldDrink.id }))

        // 4. With Health denied or unavailable, Today logging and maintenance still work normally.
        client.authorization = .denied
        let (deniedDrink, deniedTask) = try TodayView.logAndReconcile(
            preset: beerPreset,
            logService: service,
            healthSync: healthSync
        )
        let deniedStatus = await deniedTask.value
        #expect(deniedStatus == .notAuthorized)
        #expect(try service.drinks().map(\.id) == [deniedDrink.id])
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

    @Test("Onboarding gating respects first run, completed state, and skips when store already has drinks")
    @MainActor
    func onboardingGatingFirstRunCompletedAndStoreAlreadyHasDrinks() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Self.makeDate(2026, 10, 23, 10, 0, in: Self.berlinTimeZone)
        let service = LogService(
            context: container.mainContext,
            now: { t0 },
            timeZone: { Self.berlinTimeZone }
        )
        try service.seedDefaultPresetsIfNeeded()

        let suiteName = "test-onboarding-\(UUID().uuidString)"
        let testDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }

        // 1. First run, no drinks in store, not completed in defaults -> should show onboarding
        #expect(!OnboardingPreferences.isCompleted(in: testDefaults))
        #expect(OnboardingGating.shouldShowOnboarding(logService: service, defaults: testDefaults))

        // 2. User completes onboarding -> should not show
        OnboardingPreferences.setCompleted(true, in: testDefaults)
        #expect(OnboardingPreferences.isCompleted(in: testDefaults))
        #expect(!OnboardingGating.shouldShowOnboarding(logService: service, defaults: testDefaults))

        // 3. Reset defaults to simulate fresh install / restored device where store has drinks
        OnboardingPreferences.reset(in: testDefaults)
        #expect(!OnboardingPreferences.isCompleted(in: testDefaults))

        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        _ = try service.log(preset: beer, at: t0, source: .phone)

        // Store already has drinks -> should skip onboarding and mark completed
        let shouldShow = OnboardingGating.shouldShowOnboarding(logService: service, defaults: testDefaults)
        #expect(!shouldShow)
        #expect(OnboardingPreferences.isCompleted(in: testDefaults))
    }

    @Test(
        "Log earlier offsets correctly compute timestamps and cross 07:00 boundary backwards into previous logical day"
    )
    @MainActor
    func logEarlierOffsetsAndBoundaryCrossing() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0720 = Self.makeDate(2026, 10, 23, 7, 20, in: Self.berlinTimeZone)
        let clock = LockIsolated(t0720)
        let service = LogService(
            context: container.mainContext,
            now: { clock.value },
            timeZone: { Self.berlinTimeZone }
        )
        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))

        let client = InMemoryHealthStoreClient()
        let healthSync = HealthSync(
            context: container.mainContext,
            client: client,
            isEnabled: { true }
        )

        // 1. Offset duration seconds
        #expect(EarlierOffset.minutes15.seconds == 900)
        #expect(EarlierOffset.minutes30.seconds == 1800)
        #expect(EarlierOffset.hours1.seconds == 3600)
        #expect(EarlierOffset.hours2.seconds == 7200)
        #expect(EarlierOffset.hours3.seconds == 10_800)

        // 2. Localized titles
        #expect(EarlierOffset.minutes15.localizedTitle(locale: Self.englishLocale) == "15 min ago")
        #expect(EarlierOffset.minutes15.localizedTitle(locale: Self.germanLocale) == "vor 15 Min.")
        #expect(EarlierOffset.hours2.localizedTitle(locale: Self.englishLocale) == "2 h ago")
        #expect(EarlierOffset.hours2.localizedTitle(locale: Self.germanLocale) == "vor 2 Std.")

        // 3. Backward crossing of 07:00 boundary:
        // Base time: 2026-10-23 07:20 Berlin (logical day 2026-10-23)
        // Offset 30 min ago -> 2026-10-23 06:50 Berlin (logical day 2026-10-22!)
        let earlierTime = EarlierOffset.minutes30.targetTimestamp(from: t0720)
        #expect(earlierTime == Self.makeDate(2026, 10, 23, 6, 50, in: Self.berlinTimeZone))

        let (drink, reconcileTask) = try TodayView.logAndReconcile(
            preset: beer,
            at: earlierTime,
            logService: service,
            healthSync: healthSync
        )
        _ = await reconcileTask.value

        #expect(drink.timestamp == earlierTime)
        #expect(drink.logicalDay == LogicalDay(year: 2026, month: 10, day: 22))
        #expect(drink.source == .phone)

        // Apple Health sample must have been written with earlier timestamp
        #expect(client.savedSamples.count == 1)
        let sample = try #require(client.savedSamples.first)
        #expect(sample.syncIdentifier == drink.id.uuidString)
        #expect(sample.date == earlierTime)

        // Undo drink removes it from Health
        let undoTask = try TodayView.undoAndReconcile(
            drink: drink,
            logService: service,
            healthSync: healthSync
        )
        _ = await undoTask.value

        #expect(client.deletedIdentifiers.contains(drink.id.uuidString))
        let remainingDrinks = try service.drinks(includeDeleted: false)
        #expect(remainingDrinks.isEmpty)
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

private final class InMemoryHealthStoreClient: HealthStoreClient, @unchecked Sendable {
    var isAvailable = true
    var authorization: HealthWriteAuthorization = .authorized
    private(set) var savedSamples: [HealthDrinkSample] = []
    private(set) var deletedIdentifiers: [String] = []

    func writeAuthorization() async -> HealthWriteAuthorization {
        guard isAvailable else {
            return .unavailable
        }
        return authorization
    }

    func requestWriteAuthorization() async throws {}

    func save(_ samples: [HealthDrinkSample]) async throws {
        savedSamples.append(contentsOf: samples)
    }

    func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
        deletedIdentifiers.append(contentsOf: ids)
    }
}
