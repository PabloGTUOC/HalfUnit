import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("Sync Payloads and Drink De-duplication Tests")
@MainActor
struct SyncAndDedupeTests {
    private static let berlin = TimeZone(identifier: "Europe/Berlin")!
    private static let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    private static func dec(_ string: String) -> Decimal {
        guard let value = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) else {
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
        timeZone: TimeZone = SyncAndDedupeTests.berlin
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

    private final class FakeHealthClient: HealthStoreClient, @unchecked Sendable {
        var isAvailable = true
        var authorization: HealthWriteAuthorization = .authorized
        private(set) var savedBatches: [[HealthDrinkSample]] = []
        private(set) var deletedBatches: [[String]] = []

        func writeAuthorization() async -> HealthWriteAuthorization {
            authorization
        }

        func requestWriteAuthorization() async throws {}

        func save(_ samples: [HealthDrinkSample]) async throws {
            savedBatches.append(samples)
        }

        func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
            deletedBatches.append(ids)
        }
    }

    private struct Harness {
        let container: ModelContainer
        let context: ModelContext
        let clock: MutableClock
        let logService: LogService
        let healthClient: FakeHealthClient
        let healthSync: HealthSync
    }

    private func makeHarness(
        now: Date = SyncAndDedupeTests.makeDate(year: 2026, month: 10, day: 22, hour: 19, minute: 0),
        timeZone: TimeZone = SyncAndDedupeTests.berlin
    ) throws -> Harness {
        let container = try ModelContainerFactory.make(
            storeURL: nil,
            cloudKitContainerIdentifier: nil,
            inMemory: true
        )
        let context = container.mainContext
        let clock = MutableClock(now: now, timeZone: timeZone)
        let logService = LogService(
            context: context,
            now: { clock.currentNow },
            timeZone: { clock.currentTimeZone }
        )
        let healthClient = FakeHealthClient()
        let healthSync = HealthSync(
            context: context,
            client: healthClient,
            isEnabled: { true }
        )
        return Harness(
            container: container,
            context: context,
            clock: clock,
            logService: logService,
            healthClient: healthClient,
            healthSync: healthSync
        )
    }

    @Test("drinks() and snapshots() deduplicate live/live, live/tombstone, and tie-break deterministically")
    func drinksAndSnapshotsDeduplicationAndTieBreaking() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 0)
        let harness = try makeHarness(now: t0)
        let context = harness.context
        let service = harness.logService
        try service.seedDefaultPresetsIfNeeded()

        // 1. Live/live with different updatedAt: newer updatedAt wins
        let id1 = UUID()
        let olderLive = Drink(
            id: id1,
            timestamp: t0,
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Beer Old",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            createdAt: t0,
            updatedAt: t0
        )
        let newerLive = Drink(
            id: id1,
            timestamp: t0,
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Beer Edited",
            huHalfSteps: 3,
            volumeMl: 750,
            abvTenths: 50,
            centigrams: 3000,
            sourceRaw: DrinkSource.phone.rawValue,
            healthSyncVersion: 1,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(30)
        )
        context.insert(olderLive)
        context.insert(newerLive)

        // 2. Tie on updatedAt -> higher healthSyncVersion wins
        let id2 = UUID()
        let lowVersion = Drink(
            id: id2,
            timestamp: t0.addingTimeInterval(60),
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Wine v0",
            huHalfSteps: 2,
            centigrams: 1920,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            createdAt: t0,
            updatedAt: t0
        )
        let highVersion = Drink(
            id: id2,
            timestamp: t0.addingTimeInterval(60),
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Wine v2",
            huHalfSteps: 2,
            centigrams: 1920,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 2,
            createdAt: t0,
            updatedAt: t0
        )
        context.insert(lowVersion)
        context.insert(highVersion)

        // 3. Tie on updatedAt and healthSyncVersion -> tombstone wins over live
        let id3 = UUID()
        let liveTie = Drink(
            id: id3,
            timestamp: t0.addingTimeInterval(120),
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Shot Live",
            huHalfSteps: 2,
            centigrams: 1280,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            deletedAt: nil,
            createdAt: t0,
            updatedAt: t0
        )
        let tombstoneTie = Drink(
            id: id3,
            timestamp: t0.addingTimeInterval(120),
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_261_022,
            name: "Shot Tombstone",
            huHalfSteps: 2,
            centigrams: 1280,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            deletedAt: t0,
            createdAt: t0,
            updatedAt: t0
        )
        context.insert(liveTie)
        context.insert(tombstoneTie)
        try context.save()

        let activeDrinks = try service.drinks(includeDeleted: false)
        // id3's winner is a tombstone, so only id2 and id1 are active!
        #expect(activeDrinks.count == 2)
        #expect(activeDrinks.map(\.id) == [id2, id1])
        #expect(activeDrinks.first(where: { $0.id == id1 })?.name == "Beer Edited")
        #expect(activeDrinks.first(where: { $0.id == id2 })?.name == "Wine v2")

        let allDrinks = try service.drinks(includeDeleted: true)
        #expect(allDrinks.count == 3)
        #expect(allDrinks.first(where: { $0.id == id3 })?.deletedAt == t0)

        // StatsEngine via snapshots() does not double count
        let snaps = try service.snapshots()
        #expect(snaps.count == 2)
        let settings = try service.settings()
        let today = try service.today()
        let statsEngine = StatsEngine(drinks: snaps, firstUseDay: settings.firstUseDay, today: today)
        let periodStats = statsEngine.stats(for: .last7Days)
        // id1 winner = 1.5 HU (30g), id2 winner = 1.0 HU (19.2g) -> total 2.5 HU, 49.2g
        #expect(periodStats.drinkingDays == 1)
        #expect(periodStats.totalHU == Self.dec("2.5"))
        #expect(periodStats.totalGrams == Self.dec("49.2"))
    }

    @Test(
        "dedupeDrinks() merges healthSyncedVersion and deletedAt into winner, deletes losers, and prevents duplicate Health saves"
    )
    func dedupeDrinksMergesStateAndPreventsDuplicateHealthSaves() async throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 0)
        let harness = try makeHarness(now: t0)
        let context = harness.context
        let service = harness.logService
        try service.seedDefaultPresetsIfNeeded()
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))

        // Log and sync a drink to Health on phone (healthSyncVersion = 0, healthSyncedVersion = 0)
        let syncedDrink = try service.log(preset: beer, source: .watch)
        let initialStatus = await harness.healthSync.reconcile()
        #expect(initialStatus == .upToDate)
        #expect(syncedDrink.healthSyncedVersion == 0)
        #expect(harness.healthClient.savedBatches.count == 1)

        // Simulate CloudKit delivering a second row with the same UUID where healthSyncedVersion is nil
        // and updatedAt is slightly newer (or tied)
        let cloudDuplicate = Drink(
            id: syncedDrink.id,
            timestamp: syncedDrink.timestamp,
            timeZoneIdentifier: syncedDrink.timeZoneIdentifier,
            logicalDayKey: syncedDrink.logicalDayKey,
            presetId: syncedDrink.presetId,
            name: syncedDrink.name,
            huHalfSteps: syncedDrink.huHalfSteps,
            volumeMl: syncedDrink.volumeMl,
            abvTenths: syncedDrink.abvTenths,
            centigrams: syncedDrink.centigrams,
            note: nil,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            healthSyncedVersion: nil,
            deletedAt: nil,
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(1)
        )
        context.insert(cloudDuplicate)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Drink>()).count == 2)

        // Run dedupeDrinks(): cloudDuplicate wins by updatedAt, merges healthSyncedVersion = max(0) = 0
        let removedCount = try service.dedupeDrinks()
        #expect(removedCount == 1)

        let remainingRows = try context.fetch(FetchDescriptor<Drink>())
        #expect(remainingRows.count == 1)
        let winner = try #require(remainingRows.first)
        #expect(winner.id == syncedDrink.id)
        #expect(winner.healthSyncedVersion == 0)

        // Reconcile after dedupe makes NO duplicate save to Health
        let afterDedupeStatus = await harness.healthSync.reconcile()
        #expect(afterDedupeStatus == .upToDate)
        #expect(harness.healthClient.savedBatches.count == 1)

        // Now simulate a newer tombstone duplicate arriving from CloudKit with healthSyncedVersion = nil
        let tombstoneDuplicate = Drink(
            id: syncedDrink.id,
            timestamp: syncedDrink.timestamp,
            timeZoneIdentifier: syncedDrink.timeZoneIdentifier,
            logicalDayKey: syncedDrink.logicalDayKey,
            presetId: syncedDrink.presetId,
            name: syncedDrink.name,
            huHalfSteps: syncedDrink.huHalfSteps,
            volumeMl: syncedDrink.volumeMl,
            abvTenths: syncedDrink.abvTenths,
            centigrams: syncedDrink.centigrams,
            note: nil,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            healthSyncedVersion: nil,
            deletedAt: t0.addingTimeInterval(10),
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(10)
        )
        context.insert(tombstoneDuplicate)
        try context.save()

        let removedTombstoneDedupe = try service.dedupeDrinks()
        #expect(removedTombstoneDedupe == 1)
        let afterTombstoneRows = try context.fetch(FetchDescriptor<Drink>())
        #expect(afterTombstoneRows.count == 1)
        let tombstoneWinner = try #require(afterTombstoneRows.first)
        #expect(tombstoneWinner.deletedAt == t0.addingTimeInterval(10))
        // Because healthSyncedVersion (0) was merged into the tombstone winner, HealthSync deletes the sample!
        #expect(tombstoneWinner.healthSyncedVersion == 0)

        let deleteStatus = await harness.healthSync.reconcile()
        #expect(deleteStatus == .upToDate)
        #expect(harness.healthClient.deletedBatches == [[syncedDrink.id.uuidString]])
        #expect(tombstoneWinner.healthSyncedVersion == nil)
    }

    @Test(
        "DrinkTransfer and WatchStateContext plist dictionary and Codable round trips, nil optionals, and unknown schema"
    )
    func payloadRoundTripsAndSchemaValidation() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 30)
        let drinkId = UUID()
        let presetId = UUID()

        // 1. Full DrinkTransfer with all optionals populated
        let fullTransfer = DrinkTransfer(
            id: drinkId,
            timestamp: t0,
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            presetId: presetId,
            name: "beer",
            huHalfSteps: 3,
            volumeMl: 500,
            abvTenths: 52,
            centigrams: 2080,
            note: "Evening pint",
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 2,
            deletedAt: t0.addingTimeInterval(120),
            createdAt: t0,
            updatedAt: t0.addingTimeInterval(120)
        )
        let fullDict = fullTransfer.toDictionary()
        #expect(PropertyListSerialization.propertyList(fullDict, isValidFor: .binary))
        let decodedFull = try #require(DrinkTransfer(dictionary: fullDict))
        #expect(decodedFull == fullTransfer)
        #expect(decodedFull.hu == Self.dec("1.5"))
        #expect(decodedFull.abvPercent == Self.dec("5.2"))
        #expect(decodedFull.grams == Self.dec("20.8"))

        // 2. DrinkTransfer with nil optionals
        let minimalTransfer = DrinkTransfer(
            id: UUID(),
            timestamp: t0,
            timeZoneIdentifier: "Asia/Tokyo",
            logicalDayKey: 20_261_023,
            presetId: nil,
            name: "Custom",
            huHalfSteps: 1,
            volumeMl: nil,
            abvTenths: nil,
            centigrams: 1000,
            note: nil,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            deletedAt: nil,
            createdAt: t0,
            updatedAt: t0
        )
        let minimalDict = minimalTransfer.toDictionary()
        #expect(PropertyListSerialization.propertyList(minimalDict, isValidFor: .binary))
        #expect(minimalDict["presetId"] == nil)
        #expect(minimalDict["volumeMl"] == nil)
        #expect(minimalDict["abvTenths"] == nil)
        #expect(minimalDict["note"] == nil)
        #expect(minimalDict["deletedAt"] == nil)
        let decodedMinimal = try #require(DrinkTransfer(dictionary: minimalDict))
        #expect(decodedMinimal == minimalTransfer)

        // Unknown schema on DrinkTransfer -> ignored (nil)
        var futureTransferDict = minimalDict
        futureTransferDict["schema"] = 99
        #expect(DrinkTransfer(dictionary: futureTransferDict) == nil)

        // 3. WatchStateContext plist round trip with decimal string and integer fallback
        let stateContext = WatchStateContext(
            currentStreakDays: 0,
            isDrinkingToday: true,
            todayHUDecimal: Self.dec("1.5"),
            todayLogicalDayKey: 20_261_022,
            generatedAt: t0
        )
        #expect(stateContext.todayHU == "1.5")
        #expect(stateContext.todayHUDecimal == Self.dec("1.5"))

        let stateDict = stateContext.toDictionary()
        #expect(PropertyListSerialization.propertyList(stateDict, isValidFor: .binary))
        #expect(stateDict["todayHU"] as? String == "1.5")
        let decodedState = try #require(WatchStateContext(dictionary: stateDict))
        #expect(decodedState == stateContext)

        // Integer todayHU in dictionary decodes cleanly as string decimal
        var intHUDict = stateDict
        intHUDict["todayHU"] = 2
        let decodedIntHU = try #require(WatchStateContext(dictionary: intHUDict))
        #expect(decodedIntHU.todayHU == "2")
        #expect(decodedIntHU.todayHUDecimal == Decimal(2))

        // Unknown schema on WatchStateContext -> ignored (nil)
        var futureStateDict = stateDict
        futureStateDict["schema"] = 2
        #expect(WatchStateContext(dictionary: futureStateDict) == nil)
    }

    @Test(
        "DrinkTransferApplier upserts by id: newer wins, older ignored, tombstone propagates, idempotent, preserves healthSyncedVersion"
    )
    func drinkTransferApplierUpsertAndIdempotency() async throws {
        let t0 = Self.makeDate(year: 2026, month: 3, day: 29, hour: 1, minute: 30, timeZone: Self.berlin)
        // 2026-03-29 01:30 Berlin (DST spring-forward day, before 07:00 boundary) -> logical day 2026-03-28
        let harness = try makeHarness(now: t0, timeZone: Self.berlin)
        let applier = DrinkTransferApplier(context: harness.context)

        let drinkId = UUID()
        let initialTransfer = DrinkTransfer(
            id: drinkId,
            timestamp: t0,
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: 20_260_328,
            presetId: nil,
            name: "beer",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            note: nil,
            sourceRaw: DrinkSource.watch.rawValue,
            healthSyncVersion: 0,
            deletedAt: nil,
            createdAt: t0,
            updatedAt: t0
        )

        // 1. Insert new row
        let appliedFirst = try applier.apply(initialTransfer)
        #expect(appliedFirst)
        #expect(try harness.context.fetch(FetchDescriptor<Drink>()).count == 1)

        // 2. Idempotency: applying the exact same transfer again is ignored and leaves one row
        let appliedDuplicate = try applier.apply(initialTransfer)
        #expect(!appliedDuplicate)
        #expect(try harness.context.fetch(FetchDescriptor<Drink>()).count == 1)

        // Reconcile with Health so healthSyncedVersion becomes 0
        _ = await harness.healthSync.reconcile()
        let storedDrink = try #require(try harness.logService.drinks().first)
        #expect(storedDrink.healthSyncedVersion == 0)
        #expect(storedDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))

        // 3. Older transfer is ignored
        var olderTransfer = initialTransfer
        olderTransfer.name = "Stale Name"
        olderTransfer.updatedAt = t0.addingTimeInterval(-10)
        let appliedOlder = try applier.apply(olderTransfer)
        #expect(!appliedOlder)
        #expect(storedDrink.name == "beer")

        // 4. Newer transfer updates fields without touching healthSyncedVersion
        var newerTransfer = initialTransfer
        newerTransfer.huHalfSteps = 3
        newerTransfer.centigrams = 3000
        newerTransfer.healthSyncVersion = 1
        newerTransfer.updatedAt = t0.addingTimeInterval(20)
        let appliedNewer = try applier.apply(newerTransfer)
        #expect(appliedNewer)
        #expect(storedDrink.hu == Self.dec("1.5"))
        #expect(storedDrink.healthSyncVersion == 1)
        #expect(storedDrink.healthSyncedVersion == 0)

        // 5. Newer tombstone transfer propagates deletedAt while preserving healthSyncedVersion
        var tombstoneTransfer = newerTransfer
        tombstoneTransfer.deletedAt = t0.addingTimeInterval(40)
        tombstoneTransfer.updatedAt = t0.addingTimeInterval(40)
        let appliedTombstone = try applier.apply(tombstoneTransfer)
        #expect(appliedTombstone)
        #expect(storedDrink.deletedAt == t0.addingTimeInterval(40))
        #expect(storedDrink.healthSyncedVersion == 0)

        // Dedupe + HealthSync deletes the sample from Health
        _ = try harness.logService.dedupeDrinks()
        _ = await harness.healthSync.reconcile()
        #expect(harness.healthClient.deletedBatches == [[drinkId.uuidString]])
        #expect(storedDrink.healthSyncedVersion == nil)
    }

    @Test("WatchStateContext.make handles 07:00 boundary, 01:30 drink, DST transition, and time-zone change")
    func watchStateContextGenerationAcrossBoundaries() throws {
        let satEvening = Self.makeDate(year: 2026, month: 3, day: 28, hour: 21, minute: 0, timeZone: Self.berlin)
        let harness = try makeHarness(now: satEvening, timeZone: Self.berlin)
        let service = harness.logService
        try service.seedDefaultPresetsIfNeeded()
        let smallWine = try #require(try service.presets().first(where: { $0.key == "smallWine" }))
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))

        // Log at 01:30 on DST spring-forward Sunday (2026-03-29 in Berlin) -> belongs to 2026-03-28
        let sun0130 = Self.makeDate(year: 2026, month: 3, day: 29, hour: 1, minute: 30, timeZone: Self.berlin)
        harness.clock.currentNow = sun0130
        _ = try service.log(preset: smallWine, source: .phone)
        _ = try service.log(preset: beer, source: .phone)

        // Before 07:00 boundary (at 06:59): still drinking today (1.5 HU on 2026-03-28)
        let sun0659 = Self.makeDate(year: 2026, month: 3, day: 29, hour: 6, minute: 59, timeZone: Self.berlin)
        harness.clock.currentNow = sun0659
        let beforeBoundary = try WatchStateContext.make(from: service, generatedAt: sun0659)
        #expect(beforeBoundary.isDrinkingToday)
        #expect(beforeBoundary.currentStreakDays == 0)
        #expect(beforeBoundary.todayHU == "1.5")
        #expect(beforeBoundary.todayLogicalDayKey == 20_260_328)

        // At 07:00 on Sunday 2026-03-29: new logical day -> 1 day streak, 0 HU today
        let sun0700 = Self.makeDate(year: 2026, month: 3, day: 29, hour: 7, minute: 0, timeZone: Self.berlin)
        harness.clock.currentNow = sun0700
        let afterBoundary = try WatchStateContext.make(from: service, generatedAt: sun0700)
        #expect(!afterBoundary.isDrinkingToday)
        #expect(afterBoundary.currentStreakDays == 1)
        #expect(afterBoundary.todayHU == "0")
        #expect(afterBoundary.todayLogicalDayKey == 20_260_329)

        // Switch time zone to Asia/Tokyo on Monday 2026-03-30 -> 2 days streak
        let monTokyo = Self.makeDate(year: 2026, month: 3, day: 30, hour: 12, minute: 0, timeZone: Self.tokyo)
        harness.clock.currentTimeZone = Self.tokyo
        harness.clock.currentNow = monTokyo
        let mondayContext = try WatchStateContext.make(from: service, generatedAt: monTokyo)
        #expect(!mondayContext.isDrinkingToday)
        #expect(mondayContext.currentStreakDays == 2)
        #expect(mondayContext.todayHU == "0")
        #expect(mondayContext.todayLogicalDayKey == 20_260_330)
    }
}
