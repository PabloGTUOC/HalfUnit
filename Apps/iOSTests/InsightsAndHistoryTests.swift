import Foundation
import HalfUnitCore
import SwiftData
import Testing

@testable import HalfUnit

@Suite("Insights and History Tests")
struct InsightsAndHistoryTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")
    private static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!
    private static let tokyoTimeZone = TimeZone(identifier: "Asia/Tokyo")!

    private static func dec(_ string: String) -> Decimal {
        Decimal(string: string)!
    }

    private static func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 20,
        _ minute: Int = 0,
        in timeZone: TimeZone = berlinTimeZone
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

    @Test("InsightsSummaryModel formats 'x of n days' vs 'x of n tracked days' and display units")
    func insightsSummaryDaysAndUnitsFormatting() {
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        // 40 tracked days in a 91-day (3m) window
        let firstUse40 = today.adding(days: -39)
        var drinks40: [DrinkSnapshot] = []
        for index in 0..<18 {
            let day = firstUse40.adding(days: index * 2)
            drinks40.append(
                DrinkSnapshot(
                    id: UUID(),
                    timestamp: Self.makeDate(day.year, day.month, day.day),
                    logicalDay: day,
                    presetKey: "beer",
                    name: "beer",
                    hu: Decimal(1),
                    grams: Self.dec("19.2")
                )
            )
        }

        let engineTracked = StatsEngine(drinks: drinks40, firstUseDay: firstUse40, today: today)
        let snapshotTrackedEn = InsightsScreenSnapshot(
            engine: engineTracked,
            hasAnyTrackedDrinks: true,
            periodOption: .last3Months,
            period: .last3Months,
            displayUnit: .hu,
            locale: Self.englishLocale
        )
        #expect(snapshotTrackedEn.summary.drinkingDaysText == "18 of 40 tracked days")
        #expect(snapshotTrackedEn.summary.drinkingDayShareText == "45% of days")
        #expect(snapshotTrackedEn.summary.alcoholFreeDaysText == "22 alcohol-free days")
        #expect(snapshotTrackedEn.summary.totalPrimaryText == "18 HU")
        // 18 * 19.2 = 345.6 g -> rounded to 346 g
        #expect(snapshotTrackedEn.summary.totalSecondaryText == "346 g")
        #expect(snapshotTrackedEn.summary.averagePerDrinkingDayText == "1 HU")

        let snapshotTrackedDe = InsightsScreenSnapshot(
            engine: engineTracked,
            hasAnyTrackedDrinks: true,
            periodOption: .last3Months,
            period: .last3Months,
            displayUnit: .germanStandardDrinks,
            locale: Self.germanLocale
        )
        #expect(snapshotTrackedDe.summary.drinkingDaysText == "18 von 40 erfassten Tagen")
        // 345.6 g / 10 = 34.56 -> 34,6 Std.-Getränke
        #expect(snapshotTrackedDe.summary.totalPrimaryText == "34,6 Std.-Getränke")
        #expect(snapshotTrackedDe.summary.totalSecondaryText == "18 HU · 346 g")

        // Full 91-day tracked history -> "18 of 91 days"
        let firstUseFull = today.adding(days: -120)
        let engineFull = StatsEngine(drinks: drinks40, firstUseDay: firstUseFull, today: today)
        let snapshotFullEn = InsightsScreenSnapshot(
            engine: engineFull,
            hasAnyTrackedDrinks: true,
            periodOption: .last3Months,
            period: .last3Months,
            displayUnit: .ukUnits,
            locale: Self.englishLocale
        )
        #expect(snapshotFullEn.summary.drinkingDaysText == "18 of 91 days")
        // 345.6 g / 8 = 43.2 UK units
        #expect(snapshotFullEn.summary.totalPrimaryText == "43.2 UK units")
    }

    @Test("InsightsSummaryModel formats negative, positive, zero, and nil deltas neutrally")
    func insightsDeltaWording() {
        #expect(
            InsightsSummaryModel.formatDelta(
                nil,
                periodOption: .last3Months,
                locale: Self.englishLocale
            ) == nil
        )
        #expect(
            InsightsSummaryModel.formatDelta(
                -4,
                periodOption: .last3Months,
                locale: Self.englishLocale
            ) == "−4 drinking days vs previous 3 months"
        )
        #expect(
            InsightsSummaryModel.formatDelta(
                -1,
                periodOption: .last3Months,
                locale: Self.englishLocale
            ) == "−1 drinking day vs previous 3 months"
        )
        #expect(
            InsightsSummaryModel.formatDelta(
                3,
                periodOption: .last30Days,
                locale: Self.englishLocale
            ) == "+3 drinking days vs previous 30 days"
        )
        #expect(
            InsightsSummaryModel.formatDelta(
                0,
                periodOption: .last7Days,
                locale: Self.englishLocale
            ) == "Same drinking days as previous 7 days"
        )
        #expect(
            InsightsSummaryModel.formatDelta(
                -4,
                periodOption: .last3Months,
                locale: Self.germanLocale
            ) == "−4 Trinktage vs. vorherige 3 Monaten"
        )
    }

    @Test("Heatmap summary accessibility string pluralizes drinkingDays and trackedDays independently in en and de")
    func heatmapSummaryAccessibilityPluralization() {
        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 1,
                trackedDays: 1,
                locale: Self.englishLocale
            ) == "Calendar heatmap: 1 drinking day in 1 tracked day"
        )
        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 1,
                trackedDays: 2,
                locale: Self.englishLocale
            ) == "Calendar heatmap: 1 drinking day in 2 tracked days"
        )
        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 3,
                trackedDays: 91,
                locale: Self.englishLocale
            ) == "Calendar heatmap: 3 drinking days in 91 tracked days"
        )

        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 1,
                trackedDays: 1,
                locale: Self.germanLocale
            ) == "Kalenderübersicht: 1 Trinktag in 1 erfasstem Tag"
        )
        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 1,
                trackedDays: 2,
                locale: Self.germanLocale
            ) == "Kalenderübersicht: 1 Trinktag in 2 erfassten Tagen"
        )
        #expect(
            InsightsScreenSnapshot.buildHeatmapSummaryAccessibility(
                drinkingDays: 3,
                trackedDays: 91,
                locale: Self.germanLocale
            ) == "Kalenderübersicht: 3 Trinktage in 91 erfassten Tagen"
        )
    }

    @Test("InsightsScreenSnapshot formats top weekday sentence, drink-type breakdown, heatmap cells, and streaks")
    func insightsTopWeekdayHeatmapAndBreakdowns() {
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        let firstUse = today.adding(days: -90)

        // Create 17 drinking days in 3m: 7 Fridays (7 / 17 = 41.17% -> 41%), 6 Saturdays, 4 Thursdays
        var drinks: [DrinkSnapshot] = []
        var friCount = 0
        var satCount = 0
        var thuCount = 0

        var cursor = firstUse
        while cursor <= today {
            if cursor.weekday == .friday, friCount < 7 {
                drinks.append(
                    DrinkSnapshot(
                        id: UUID(),
                        timestamp: Self.makeDate(cursor.year, cursor.month, cursor.day),
                        logicalDay: cursor,
                        presetKey: "beer",
                        name: "beer",
                        hu: Decimal(1),
                        grams: Decimal(20)
                    )
                )
                friCount += 1
            } else if cursor.weekday == .saturday, satCount < 6 {
                drinks.append(
                    DrinkSnapshot(
                        id: UUID(),
                        timestamp: Self.makeDate(cursor.year, cursor.month, cursor.day),
                        logicalDay: cursor,
                        presetKey: "wineGlass",
                        name: "wineGlass",
                        hu: Self.dec("1.5"),
                        grams: Self.dec("28.8")
                    )
                )
                satCount += 1
            } else if cursor.weekday == .thursday, thuCount < 4 {
                drinks.append(
                    DrinkSnapshot(
                        id: UUID(),
                        timestamp: Self.makeDate(cursor.year, cursor.month, cursor.day),
                        logicalDay: cursor,
                        presetKey: nil,
                        name: "Mass 1L",
                        hu: Decimal(2),
                        grams: Decimal(40)
                    )
                )
                thuCount += 1
            }
            cursor = cursor.adding(days: 1)
        }

        let engine = StatsEngine(drinks: drinks, firstUseDay: firstUse, today: today)
        let snapshotEn = InsightsScreenSnapshot(
            engine: engine,
            hasAnyTrackedDrinks: true,
            periodOption: .last3Months,
            period: .last3Months,
            displayUnit: .hu,
            locale: Self.englishLocale
        )

        #expect(snapshotEn.topWeekdaySentence == "Fridays are 41% of your drinking days")
        #expect(snapshotEn.weekdayRows.count == 7)
        #expect(snapshotEn.weekdayRows.first(where: { $0.weekday == .friday })?.isTop == true)
        #expect(snapshotEn.heatmapCells.count == 91)

        // Check localized preset names and custom drink name in drinkTypeRows
        let typeNamesEn = snapshotEn.drinkTypeRows.map(\.name)
        #expect(typeNamesEn.contains("Wine glass"))
        #expect(typeNamesEn.contains("Mass 1L"))
        #expect(typeNamesEn.contains("Beer"))

        let snapshotDe = InsightsScreenSnapshot(
            engine: engine,
            hasAnyTrackedDrinks: true,
            periodOption: .last3Months,
            period: .last3Months,
            displayUnit: .hu,
            locale: Self.germanLocale
        )
        #expect(snapshotDe.topWeekdaySentence == "Freitage machen 41% deiner Trinktage aus")
        let typeNamesDe = snapshotDe.drinkTypeRows.map(\.name)
        #expect(typeNamesDe.contains("Glas Wein"))
        #expect(typeNamesDe.contains("Mass 1L"))
        #expect(typeNamesDe.contains("Bier"))
    }

    @Test("InsightsPeriodOption customPeriod respects 07:00 boundary, 01:30 timestamp, DST week, and time-zone change")
    func customPeriodBoundaryDSTAndTimeZone() {
        // 01:30 on Sunday 2026-03-29 (Europe/Berlin spring DST day) belongs to logical Saturday 2026-03-28
        let start0130 = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        // 07:00 on Sunday 2026-03-29 belongs to logical Sunday 2026-03-29
        let end0700 = Self.makeDate(2026, 3, 29, 7, 0, in: Self.berlinTimeZone)

        let berlinPeriod = InsightsPeriodOption.customPeriod(
            from: start0130,
            through: end0700,
            boundaryHour: 7,
            timeZone: Self.berlinTimeZone
        )
        #expect(
            berlinPeriod
                == .custom(
                    from: LogicalDay(year: 2026, month: 3, day: 28),
                    through: LogicalDay(year: 2026, month: 3, day: 29)
                )
        )

        // Same start0130 instant in Asia/Tokyo is 09:30 on 2026-03-29 (>= 07:00), so logical day is 2026-03-29
        let tokyoPeriod = InsightsPeriodOption.customPeriod(
            from: start0130,
            through: end0700,
            boundaryHour: 7,
            timeZone: Self.tokyoTimeZone
        )
        #expect(
            tokyoPeriod
                == .custom(
                    from: LogicalDay(year: 2026, month: 3, day: 29),
                    through: LogicalDay(year: 2026, month: 3, day: 29)
                )
        )
    }

    @Test(
        "PRODUCT.md acceptance: Insights for 3 m / 12 m / 2 y show correct drinking-day counts against a seeded in-memory dataset"
    )
    @MainActor
    func productAcceptanceSeededDatasetThroughLogServiceAndInsightsModel() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let today = LogicalDay(year: 2026, month: 10, day: 22)
        let firstUseDay = today.adding(days: -849)
        let nowDate = Self.makeDate(2026, 10, 22, 20, 0, in: Self.berlinTimeZone)

        let currentNow = LockIsolatedDate(nowDate)
        let currentZone = LockIsolatedZone(Self.berlinTimeZone)
        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )

        try service.seedDefaultPresetsIfNeeded()
        let settings = try service.settings()
        settings.firstUseDay = firstUseDay

        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))
        let smallBeer = try #require(presets.first(where: { $0.key == "smallBeer" }))

        // Seed 850 days: every Friday (1 beer), every Saturday (2 wine glasses),
        // plus extra boundary days (-6, -7, -29, -30, -90, -91, -364, -365, -729, -730).
        let extraOffsets: Set<Int> = [-6, -7, -29, -30, -90, -91, -364, -365, -729, -730]
        let extraDays = Set(extraOffsets.map { today.adding(days: $0) })

        var cursor = firstUseDay
        while cursor <= today {
            if cursor.weekday == .friday {
                let ts = Self.makeDate(cursor.year, cursor.month, cursor.day, 19, 0, in: Self.berlinTimeZone)
                _ = try service.log(preset: beer, at: ts, source: .phone)
            } else if cursor.weekday == .saturday {
                let ts1 = Self.makeDate(cursor.year, cursor.month, cursor.day, 20, 0, in: Self.berlinTimeZone)
                let ts2 = Self.makeDate(cursor.year, cursor.month, cursor.day, 21, 0, in: Self.berlinTimeZone)
                _ = try service.log(preset: wine, at: ts1, source: .phone)
                _ = try service.log(preset: wine, at: ts2, source: .phone)
            } else if extraDays.contains(cursor) {
                let ts = Self.makeDate(cursor.year, cursor.month, cursor.day, 18, 0, in: Self.berlinTimeZone)
                _ = try service.log(preset: smallBeer, at: ts, source: .phone)
            }
            cursor = cursor.adding(days: 1)
        }

        let insights3m = try InsightsScreenSnapshot.load(
            from: service,
            periodOption: .last3Months,
            locale: Self.englishLocale
        )
        #expect(insights3m.summary.drinkingDaysText == "29 of 91 days")
        #expect(insights3m.summary.alcoholFreeDaysText == "62 alcohol-free days")
        #expect(insights3m.summary.totalPrimaryText == "40.5 HU")
        #expect(insights3m.summary.deltaText == "+2 drinking days vs previous 3 months")

        let insights12m = try InsightsScreenSnapshot.load(
            from: service,
            periodOption: .last12Months,
            locale: Self.englishLocale
        )
        #expect(insights12m.summary.drinkingDaysText == "109 of 365 days")
        #expect(insights12m.summary.alcoholFreeDaysText == "256 alcohol-free days")
        #expect(insights12m.summary.totalPrimaryText == "158.5 HU")

        let insights2y = try InsightsScreenSnapshot.load(
            from: service,
            periodOption: .last2Years,
            locale: Self.englishLocale
        )
        #expect(insights2y.summary.drinkingDaysText == "215 of 730 days")
        #expect(insights2y.summary.alcoholFreeDaysText == "515 alcohol-free days")
        #expect(insights2y.summary.totalPrimaryText == "315.5 HU")
    }

    @Test(
        "HistoryScreenSnapshot groups by logical day, computes day totals, filters by search, and edits/deletes with Health reconcile"
    )
    @MainActor
    func historyGroupingSearchEditAndDelete() async throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Self.makeDate(2026, 10, 22, 21, 0, in: Self.berlinTimeZone)
        let currentNow = LockIsolatedDate(t0)
        let currentZone = LockIsolatedZone(Self.berlinTimeZone)

        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )
        let healthClient = FakeHistoryHealthClient()
        let healthSync = HealthSync(
            context: container.mainContext,
            client: healthClient,
            isEnabled: { true }
        )

        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))
        let shot = try #require(presets.first(where: { $0.key == "shot" }))

        // Empty state first
        let emptySnapshot = try HistoryScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(emptySnapshot.isEmptyStore)
        #expect(emptySnapshot.sections.isEmpty)

        // Log 1 beer on Thursday evening (2026-10-22 21:00) and 1 wine at 01:30 Friday morning (still logical day 2026-10-22!)
        let d1 = try service.log(preset: beer, at: t0, source: .phone)
        let tLate = Self.makeDate(2026, 10, 23, 1, 30, in: Self.berlinTimeZone)
        let d2 = try service.log(preset: wine, at: tLate, source: .phone)
        try service.edit(d2, DrinkEdit(note: .set("Birthday dinner")))

        // Log 1 custom drink on Friday evening (2026-10-23 20:00)
        let tFri = Self.makeDate(2026, 10, 23, 20, 0, in: Self.berlinTimeZone)
        currentNow.setValue(tFri)
        let d3 = try service.logCustom(
            name: "Aperol Spritz",
            hu: Self.dec("1.5"),
            volumeMl: 250,
            abvPercent: Decimal(11),
            at: tFri,
            source: .phone
        )
        await HalfUnitApp.reconcileHealth(healthSync: healthSync)

        // Verify reverse-chronological grouping by logical day and day totals
        let fullHistory = try HistoryScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(!fullHistory.isEmptyStore)
        #expect(fullHistory.sections.count == 2)
        #expect(fullHistory.sections[0].day == LogicalDay(year: 2026, month: 10, day: 23))
        #expect(fullHistory.sections[0].totalHU == Self.dec("1.5"))
        #expect(fullHistory.sections[0].totalDisplayText == "Total: 1.5 HU")
        #expect(fullHistory.sections[0].items.map(\.id) == [d3.id])

        #expect(fullHistory.sections[1].day == LogicalDay(year: 2026, month: 10, day: 22))
        #expect(fullHistory.sections[1].totalHU == Decimal(2))
        #expect(fullHistory.sections[1].totalDisplayText == "Total: 2 HU")
        #expect(fullHistory.sections[1].items.map(\.id) == [d2.id, d1.id])

        // Search by localized preset name in German ("Glas Wein")
        let searchWineDe = try HistoryScreenSnapshot.load(
            from: service,
            searchQuery: "Glas Wein",
            locale: Self.germanLocale
        )
        #expect(searchWineDe.sections.count == 1)
        #expect(searchWineDe.sections[0].items.map(\.id) == [d2.id])

        // Search by note ("Birthday")
        let searchNote = try HistoryScreenSnapshot.load(
            from: service,
            searchQuery: "birthday",
            locale: Self.englishLocale
        )
        #expect(searchNote.sections.count == 1)
        #expect(searchNote.sections[0].items.map(\.id) == [d2.id])

        // Search with no match -> isSearchEmpty = true
        let searchNone = try HistoryScreenSnapshot.load(
            from: service,
            searchQuery: "nonexistent",
            locale: Self.englishLocale
        )
        #expect(!searchNone.isEmptyStore)
        #expect(searchNone.isSearchEmpty)
        #expect(searchNone.sections.isEmpty)

        // Test HistoryDrinkEditDraft preset change + explicit HU override -> HistoryView.editAndReconcile
        let d1Item = try #require(fullHistory.sections[1].items.first(where: { $0.id == d1.id }))
        let shotOption = try #require(fullHistory.presetOptions.first(where: { $0.id == shot.id }))
        var draft = HistoryDrinkEditDraft(item: d1Item, locale: Self.englishLocale)
        draft.applyPreset(shotOption, locale: Self.englishLocale)
        #expect(draft.hu == Decimal(1))
        #expect(draft.volumeMlText == "40")
        draft.stepHU(by: 1)  // Override HU to 1.5
        draft.noteText = "Double shot"

        let drinkEdit = draft.buildDrinkEdit(presets: fullHistory.presetOptions)
        #expect(drinkEdit.presetId == shot.id)
        #expect(drinkEdit.hu == Self.dec("1.5"))
        #expect(drinkEdit.note == .set("Double shot"))

        let editTask = try HistoryView.editAndReconcile(
            drink: d1,
            edit: drinkEdit,
            logService: service,
            healthSync: healthSync
        )
        _ = await editTask.value
        #expect(d1.presetId == shot.id)
        #expect(d1.name == "shot")
        #expect(d1.hu == Self.dec("1.5"))
        #expect(d1.volumeMl == 40)
        #expect(d1.abvPercent == Decimal(40))
        #expect(d1.note == "Double shot")
        #expect(d1.healthSyncedVersion == d1.healthSyncVersion)

        // Delete d3 via HistoryView.deleteAndReconcile
        let deleteTask = try HistoryView.deleteAndReconcile(
            drink: d3,
            logService: service,
            healthSync: healthSync
        )
        _ = await deleteTask.value
        #expect(healthClient.deletedIdentifiers.contains(d3.id.uuidString))

        let afterDelete = try HistoryScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(afterDelete.sections.count == 1)
        #expect(afterDelete.sections[0].day == LogicalDay(year: 2026, month: 10, day: 22))
    }
}

private final class LockIsolatedDate: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Date

    init(_ value: Date) {
        self.storage = value
    }

    var value: Date {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func setValue(_ newValue: Date) {
        lock.lock()
        defer { lock.unlock() }
        storage = newValue
    }
}

private final class LockIsolatedZone: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: TimeZone

    init(_ value: TimeZone) {
        self.storage = value
    }

    var value: TimeZone {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func setValue(_ newValue: TimeZone) {
        lock.lock()
        defer { lock.unlock() }
        storage = newValue
    }
}

private final class FakeHistoryHealthClient: HealthStoreClient, @unchecked Sendable {
    var isAvailable = true
    var savedSamples: [HealthDrinkSample] = []
    var deletedIdentifiers: [String] = []

    func writeAuthorization() async -> HealthWriteAuthorization {
        .authorized
    }

    func requestWriteAuthorization() async throws {}

    func save(_ samples: [HealthDrinkSample]) async throws {
        savedSamples.append(contentsOf: samples)
    }

    func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
        deletedIdentifiers.append(contentsOf: ids)
    }
}
