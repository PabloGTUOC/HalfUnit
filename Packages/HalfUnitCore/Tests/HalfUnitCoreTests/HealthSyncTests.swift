import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("HealthSync Tests")
@MainActor
struct HealthSyncTests {
    private static let berlin = TimeZone(identifier: "Europe/Berlin")!

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
        timeZone: TimeZone = HealthSyncTests.berlin
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
        var isHealthEnabled: Bool

        init(now: Date, timeZone: TimeZone, isHealthEnabled: Bool = true) {
            self.currentNow = now
            self.currentTimeZone = timeZone
            self.isHealthEnabled = isHealthEnabled
        }
    }

    private struct TestHarness {
        let container: ModelContainer
        let context: ModelContext
        let clock: MutableClock
        let logService: LogService
        let client: FakeHealthStoreClient
        let healthSync: HealthSync
    }

    private func makeHarness(
        now: Date = HealthSyncTests.makeDate(year: 2026, month: 10, day: 22, hour: 19, minute: 30),
        timeZone: TimeZone = HealthSyncTests.berlin,
        isHealthEnabled: Bool = true,
        isAvailable: Bool = true,
        authorization: HealthWriteAuthorization = .authorized
    ) throws -> TestHarness {
        let container = try ModelContainerFactory.make(
            storeURL: nil,
            cloudKitContainerIdentifier: nil,
            inMemory: true
        )
        let context = container.mainContext
        let clock = MutableClock(now: now, timeZone: timeZone, isHealthEnabled: isHealthEnabled)
        let logService = LogService(
            context: context,
            now: { clock.currentNow },
            timeZone: { clock.currentTimeZone }
        )
        let client = FakeHealthStoreClient(
            isAvailable: isAvailable,
            authorization: authorization
        )
        let healthSync = HealthSync(
            context: context,
            client: client,
            isEnabled: { clock.isHealthEnabled }
        )
        return TestHarness(
            container: container,
            context: context,
            clock: clock,
            logService: logService,
            client: client,
            healthSync: healthSync
        )
    }

    @Test("New drink writes one sample with syncVersion 1, standardDrinks = grams/10, and second reconcile is a no-op")
    func newDrinkWritesSampleAndSecondReconcileMakesNoCalls() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 15)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try harness.logService.presets().first(where: { $0.key == "beer" }))

        let drink = try harness.logService.log(preset: beer, source: .phone)
        #expect(drink.healthSyncVersion == 0)
        #expect(drink.healthSyncedVersion == nil)

        let firstStatus = await harness.healthSync.reconcile()
        #expect(firstStatus == .upToDate)
        #expect(harness.healthSync.lastStatus == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        #expect(harness.client.deletedIdentifierBatches.isEmpty)

        let batch = try #require(harness.client.savedBatches.first)
        #expect(batch.count == 1)
        let sample = try #require(batch.first)
        #expect(sample.syncIdentifier == drink.id.uuidString)
        #expect(sample.syncVersion == 1)
        #expect(sample.date == logTime)
        // Beer 500 ml @ 5% = 20 g -> 2 standard drinks
        #expect(sample.standardDrinks == Decimal(2))
        #expect(sample.presetKey == "beer")
        #expect(sample.hu == Decimal(1))
        #expect(sample.grams == Decimal(20))
        #expect(sample.volumeMl == 500)
        #expect(sample.abvPercent == Decimal(5))
        #expect(drink.healthSyncedVersion == 0)

        // Second reconcile with no changes makes zero client calls
        let secondStatus = await harness.healthSync.reconcile()
        #expect(secondStatus == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        #expect(harness.client.deletedIdentifierBatches.isEmpty)
    }

    @Test(
        "Editing a drink re-saves with same syncIdentifier and strictly higher syncVersion without duplicates in one batch"
    )
    func editDrinkUpdatesSampleWithHigherVersionAndNoDuplicates() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 0)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try harness.logService.presets().first(where: { $0.key == "beer" }))

        let drink = try harness.logService.log(preset: beer, source: .phone)
        _ = await harness.healthSync.reconcile()
        #expect(drink.healthSyncedVersion == 0)
        #expect(harness.client.savedBatches.count == 1)

        // Edit once -> healthSyncVersion becomes 1 -> sample syncVersion 2
        let editedTimestamp = logTime.addingTimeInterval(-900)
        harness.clock.currentNow = logTime.addingTimeInterval(60)
        try harness.logService.edit(
            drink,
            DrinkEdit(
                timestamp: editedTimestamp,
                hu: Self.dec("1.5"),
                volumeMl: .set(750),
                abvPercent: .set(Decimal(5))
            )
        )
        #expect(drink.healthSyncVersion == 1)
        #expect(drink.healthSyncedVersion == 0)

        let statusAfterFirstEdit = await harness.healthSync.reconcile()
        #expect(statusAfterFirstEdit == .upToDate)
        #expect(harness.client.savedBatches.count == 2)
        let secondBatch = harness.client.savedBatches[1]
        #expect(secondBatch.count == 1)
        let updatedSample = try #require(secondBatch.first)
        #expect(updatedSample.syncIdentifier == drink.id.uuidString)
        #expect(updatedSample.syncVersion == 2)
        #expect(updatedSample.date == editedTimestamp)
        // 750 ml @ 5% = 30 g -> 3 standard drinks
        #expect(updatedSample.standardDrinks == Decimal(3))
        #expect(updatedSample.hu == Self.dec("1.5"))
        #expect(updatedSample.grams == Decimal(30))
        #expect(updatedSample.volumeMl == 750)
        #expect(drink.healthSyncedVersion == 1)

        // Two edits before next reconcile + simulated CloudKit duplicate row with same UUID:
        // still only one sample for that syncIdentifier in the batch
        harness.clock.currentNow = logTime.addingTimeInterval(120)
        try harness.logService.edit(drink, DrinkEdit(hu: Decimal(2), volumeMl: .clear, abvPercent: .clear))
        harness.clock.currentNow = logTime.addingTimeInterval(180)
        try harness.logService.edit(drink, DrinkEdit(note: .set("Updated twice")))
        #expect(drink.healthSyncVersion == 3)

        let staleCloudDuplicate = Drink(
            id: drink.id,
            timestamp: logTime,
            timeZoneIdentifier: Self.berlin.identifier,
            logicalDayKey: drink.logicalDayKey,
            presetId: beer.id,
            name: beer.name,
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            sourceRaw: DrinkSource.phone.rawValue,
            healthSyncVersion: 1,
            healthSyncedVersion: 0,
            deletedAt: nil,
            createdAt: logTime,
            updatedAt: logTime.addingTimeInterval(30)
        )
        harness.context.insert(staleCloudDuplicate)
        try harness.context.save()

        let statusAfterMultipleEdits = await harness.healthSync.reconcile()
        #expect(statusAfterMultipleEdits == .upToDate)
        #expect(harness.client.savedBatches.count == 3)
        let thirdBatch = harness.client.savedBatches[2]
        #expect(thirdBatch.count == 1)
        let deduplicatedSample = try #require(thirdBatch.first)
        #expect(deduplicatedSample.syncIdentifier == drink.id.uuidString)
        #expect(deduplicatedSample.syncVersion == 4)
        #expect(deduplicatedSample.standardDrinks == Decimal(4))
        #expect(deduplicatedSample.volumeMl == nil)
        #expect(deduplicatedSample.abvPercent == nil)
        #expect(drink.healthSyncedVersion == 3)
    }

    @Test(
        "Delete and undo remove synced samples from Health, clear healthSyncedVersion, and skip never-written tombstones"
    )
    func deleteAndUndoBehavior() async throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 19, minute: 0)
        let harness = try makeHarness(now: t0)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let presets = try harness.logService.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))
        let shot = try #require(presets.first(where: { $0.key == "shot" }))

        let deletedDrink = try harness.logService.log(preset: beer, source: .phone)
        let undoneDrink = try harness.logService.log(preset: wine, source: .phone)
        _ = await harness.healthSync.reconcile()
        #expect(harness.client.savedBatches.count == 1)
        #expect(deletedDrink.healthSyncedVersion == 0)
        #expect(undoneDrink.healthSyncedVersion == 0)

        // Log a third drink and immediately undo it BEFORE reconcile (never written to Health)
        harness.clock.currentNow = t0.addingTimeInterval(3)
        let neverSyncedTombstone = try harness.logService.log(preset: shot, source: .phone)
        try harness.logService.undo(neverSyncedTombstone)
        #expect(neverSyncedTombstone.deletedAt != nil)
        #expect(neverSyncedTombstone.healthSyncedVersion == nil)

        // Reconcile when only a never-written tombstone is dirty -> no save or delete calls
        let statusForNeverSynced = await harness.healthSync.reconcile()
        #expect(statusForNeverSynced == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        #expect(harness.client.deletedIdentifierBatches.isEmpty)

        // Now delete `deletedDrink` and undo `undoneDrink` after they were synced to Health
        harness.clock.currentNow = t0.addingTimeInterval(4)
        try harness.logService.delete(deletedDrink)
        try harness.logService.undo(undoneDrink)

        let statusAfterDeleteAndUndo = await harness.healthSync.reconcile()
        #expect(statusAfterDeleteAndUndo == .upToDate)
        #expect(harness.client.deletedIdentifierBatches.count == 1)
        let deletedIds = Set(harness.client.deletedIdentifierBatches[0])
        #expect(deletedIds == [deletedDrink.id.uuidString, undoneDrink.id.uuidString])
        #expect(deletedDrink.healthSyncedVersion == nil)
        #expect(undoneDrink.healthSyncedVersion == nil)

        // Subsequent reconcile makes no further delete calls
        _ = await harness.healthSync.reconcile()
        #expect(harness.client.deletedIdentifierBatches.count == 1)
    }

    @Test("Drink logged with source .watch is written to Apple Health by iPhone reconcile")
    func watchDrinkWrittenByPhoneReconcile() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 23, hour: 1, minute: 30)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let shot = try #require(try harness.logService.presets().first(where: { $0.key == "shot" }))

        let watchDrink = try harness.logService.log(preset: shot, source: .watch)
        #expect(watchDrink.source == .watch)
        #expect(watchDrink.healthSyncedVersion == nil)

        let status = await harness.healthSync.reconcile()
        #expect(status == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        let sample = try #require(harness.client.savedBatches.first?.first)
        #expect(sample.syncIdentifier == watchDrink.id.uuidString)
        #expect(sample.syncVersion == 1)
        // Shot: 40 ml @ 40% = 12.8 g -> 1.28 standard drinks (unrounded)
        #expect(sample.grams == Self.dec("12.8"))
        #expect(sample.standardDrinks == Self.dec("1.28"))
        #expect(sample.presetKey == "shot")
        #expect(watchDrink.healthSyncedVersion == 0)
    }

    @Test(
        "Disabled, unavailable, denied, and notDetermined states make no client write/delete calls and leave model unchanged"
    )
    func nonAuthorizedStatesMakeNoCallsAndPreserveAppFunctionality() async throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 0)
        let harness = try makeHarness(
            now: t0,
            isHealthEnabled: false,
            isAvailable: true,
            authorization: .authorized
        )
        try harness.logService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try harness.logService.presets().first(where: { $0.key == "beer" }))
        let drink = try harness.logService.log(preset: beer, source: .phone)

        // 1. Disabled in Settings
        let disabledStatus = await harness.healthSync.reconcile()
        #expect(disabledStatus == .disabled)
        #expect(harness.healthSync.lastStatus == .disabled)
        #expect(harness.client.savedBatches.isEmpty)
        #expect(drink.healthSyncedVersion == nil)

        // 2. HealthKit unavailable on device
        harness.clock.isHealthEnabled = true
        harness.client.isAvailable = false
        let unavailableStatus = await harness.healthSync.reconcile()
        #expect(unavailableStatus == .unavailable)
        #expect(harness.healthSync.lastStatus == .unavailable)
        #expect(harness.client.savedBatches.isEmpty)
        #expect(drink.healthSyncedVersion == nil)

        // 3. Permission notDetermined (reconcile must never prompt)
        harness.client.isAvailable = true
        harness.client.authorization = .notDetermined
        let notDeterminedStatus = await harness.healthSync.reconcile()
        #expect(notDeterminedStatus == .notAuthorized)
        #expect(harness.healthSync.lastStatus == .notAuthorized)
        #expect(harness.client.requestAuthorizationCallCount == 0)
        #expect(harness.client.savedBatches.isEmpty)
        #expect(drink.healthSyncedVersion == nil)

        // 4. Permission denied: every other feature (logging, editing, stats, streaks) works normally
        harness.client.authorization = .denied
        let deniedStatus = await harness.healthSync.reconcile()
        #expect(deniedStatus == .notAuthorized)
        #expect(harness.healthSync.lastStatus == .notAuthorized)
        #expect(harness.client.savedBatches.isEmpty)
        #expect(drink.healthSyncedVersion == nil)

        let snapshots = try harness.logService.snapshots()
        let settings = try harness.logService.settings()
        let today = try harness.logService.today()
        let engine = StatsEngine(drinks: snapshots, firstUseDay: settings.firstUseDay, today: today)
        #expect(engine.stats(for: .last7Days).drinkingDays == 1)
        #expect(engine.streaks().currentStreakDays == 0)
    }

    @Test(
        "Client save or delete failure returns .failed without user data, leaves healthSyncedVersion unchanged, and retries on next reconcile"
    )
    func clientFailureLeavesModelUnchangedAndRetriesLater() async throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 22, minute: 0)
        let harness = try makeHarness(now: t0)
        let secretNote = "PrivateVenueName123"
        let drink = try harness.logService.logCustom(
            name: "SecretCocktail999",
            hu: Decimal(1),
            source: .phone
        )
        try harness.logService.edit(drink, DrinkEdit(note: .set(secretNote)))
        #expect(drink.healthSyncVersion == 1)

        // Simulate client save error
        harness.client.saveError = FakeHealthStoreClient.Failure("Disk full")
        let failedSaveStatus = await harness.healthSync.reconcile()
        guard case .failed(let message) = failedSaveStatus else {
            Issue.record("Expected .failed status, got \(failedSaveStatus)")
            return
        }
        #expect(!message.contains("SecretCocktail999"))
        #expect(!message.contains(secretNote))
        #expect(!message.contains(drink.id.uuidString))
        #expect(drink.healthSyncedVersion == nil)
        #expect(harness.client.savedBatches.isEmpty)

        // Clear error; next reconcile succeeds and writes the drink
        harness.client.saveError = nil
        let recoveredSaveStatus = await harness.healthSync.reconcile()
        #expect(recoveredSaveStatus == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        #expect(drink.healthSyncedVersion == 1)

        // Now delete the drink and simulate a deleteSamples error
        try harness.logService.delete(drink)
        harness.client.deleteError = FakeHealthStoreClient.Failure("Delete error")
        let failedDeleteStatus = await harness.healthSync.reconcile()
        guard case .failed = failedDeleteStatus else {
            Issue.record("Expected .failed status on delete failure, got \(failedDeleteStatus)")
            return
        }
        #expect(drink.healthSyncedVersion == 1)
        #expect(harness.client.deletedIdentifierBatches.isEmpty)

        // Clear delete error; next reconcile deletes from Health and clears healthSyncedVersion
        harness.client.deleteError = nil
        let recoveredDeleteStatus = await harness.healthSync.reconcile()
        #expect(recoveredDeleteStatus == .upToDate)
        #expect(harness.client.deletedIdentifierBatches == [[drink.id.uuidString]])
        #expect(drink.healthSyncedVersion == nil)
    }

    @Test("requestAuthorization requests write access and returns updated authorization status")
    func requestAuthorizationFlow() async throws {
        let harness = try makeHarness(authorization: .notDetermined)
        harness.client.authorizationAfterRequest = .authorized

        let result = await harness.healthSync.requestAuthorization()
        #expect(result == .authorized)
        #expect(harness.client.requestAuthorizationCallCount == 1)
    }

    @Test(
        "Edit made while save() is suspended stays pending: first pass marks captured version, next reconcile saves edited drink with higher syncVersion"
    )
    func editWhileSaveSuspendedStaysPendingForNextReconcile() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 0)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try harness.logService.presets().first(where: { $0.key == "beer" }))

        let drink = try harness.logService.log(preset: beer, source: .phone)
        #expect(drink.healthSyncVersion == 0)
        #expect(drink.healthSyncedVersion == nil)

        harness.client.shouldSuspendNextSave = true
        let firstReconcileTask = Task {
            await harness.healthSync.reconcile()
        }

        await harness.client.waitForSaveToSuspend()

        // While client.save() is suspended in flight with version 0 (syncVersion 1),
        // the user edits the drink -> healthSyncVersion becomes 1.
        harness.clock.currentNow = logTime.addingTimeInterval(30)
        try harness.logService.edit(
            drink,
            DrinkEdit(
                hu: Self.dec("1.5"),
                volumeMl: .set(750),
                abvPercent: .set(Decimal(5))
            )
        )
        #expect(drink.healthSyncVersion == 1)

        // Release the suspended save() call.
        harness.client.resumeSuspendedSave()
        let firstStatus = await firstReconcileTask.value
        #expect(firstStatus == .upToDate)

        // First pass must only mark the captured version (0), leaving version 1 pending.
        #expect(drink.healthSyncedVersion == 0)
        #expect(drink.healthSyncVersion == 1)
        #expect(harness.client.savedBatches.count == 1)
        let firstSample = try #require(harness.client.savedBatches[0].first)
        #expect(firstSample.syncIdentifier == drink.id.uuidString)
        #expect(firstSample.syncVersion == 1)
        #expect(firstSample.standardDrinks == Decimal(2))

        // Next reconcile saves the edited drink with strictly higher syncVersion (2).
        let secondStatus = await harness.healthSync.reconcile()
        #expect(secondStatus == .upToDate)
        #expect(drink.healthSyncedVersion == 1)
        #expect(harness.client.savedBatches.count == 2)
        let secondSample = try #require(harness.client.savedBatches[1].first)
        #expect(secondSample.syncIdentifier == drink.id.uuidString)
        #expect(secondSample.syncVersion == 2)
        #expect(secondSample.standardDrinks == Decimal(3))
    }

    @Test(
        "Two concurrent reconcile() calls while save() is suspended run single-flight with at most one follow-up pass and no duplicate (identifier, version) pairs"
    )
    func concurrentReconcileCallsAreSingleFlightWithoutDuplicateSaves() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 0)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try harness.logService.presets().first(where: { $0.key == "beer" }))

        // Case 1: Two concurrent reconcile() calls with no intervening edits -> exactly 1 save call
        let drink = try harness.logService.log(preset: beer, source: .phone)
        harness.client.shouldSuspendNextSave = true

        let call1 = Task {
            await harness.healthSync.reconcile()
        }
        await harness.client.waitForSaveToSuspend()

        let call2 = Task {
            await harness.healthSync.reconcile()
        }
        await Task.yield()

        harness.client.resumeSuspendedSave()
        let status1 = await call1.value
        let status2 = await call2.value
        #expect(status1 == .upToDate)
        #expect(status2 == .upToDate)
        #expect(harness.client.savedBatches.count == 1)
        #expect(drink.healthSyncedVersion == 0)

        // Case 2: Edit occurs while save() is suspended and a concurrent reconcile() is requested ->
        // first pass saves version 1, automatic follow-up pass saves version 2, zero duplicates.
        harness.clock.currentNow = logTime.addingTimeInterval(60)
        try harness.logService.edit(drink, DrinkEdit(hu: Decimal(1)))
        #expect(drink.healthSyncVersion == 1)

        harness.client.shouldSuspendNextSave = true
        let call3 = Task {
            await harness.healthSync.reconcile()
        }
        await harness.client.waitForSaveToSuspend()

        // Edit again while call3's save (syncVersion 2) is suspended, then trigger overlapping call4
        harness.clock.currentNow = logTime.addingTimeInterval(120)
        try harness.logService.edit(
            drink,
            DrinkEdit(
                hu: Decimal(2),
                volumeMl: .clear,
                abvPercent: .clear
            )
        )
        #expect(drink.healthSyncVersion == 2)

        let call4 = Task {
            await harness.healthSync.reconcile()
        }
        await Task.yield()

        harness.client.resumeSuspendedSave()
        let status3 = await call3.value
        let status4 = await call4.value
        #expect(status3 == .upToDate)
        #expect(status4 == .upToDate)
        #expect(drink.healthSyncedVersion == 2)

        // Total batches across both cases: batch 0 (syncVersion 1), batch 1 (syncVersion 2), batch 2 (syncVersion 3)
        #expect(harness.client.savedBatches.count == 3)
        let allSamples = harness.client.savedBatches.flatMap { $0 }
        let pairs = allSamples.map { "\($0.syncIdentifier)#\($0.syncVersion)" }
        #expect(pairs.count == Set(pairs).count)
        #expect(allSamples.map(\.syncVersion) == [1, 2, 3])
    }

    @Test(
        "Three overlapping reconcile() calls loop until all in-flight and follow-up changes reach the store without duplicate (identifier, version) pairs"
    )
    func threeOverlappingReconcileCallsProcessAllChangesWithoutDuplicates() async throws {
        let logTime = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 30)
        let harness = try makeHarness(now: logTime)
        try harness.logService.seedDefaultPresetsIfNeeded()
        let presets = try harness.logService.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))

        let firstDrink = try harness.logService.log(preset: beer, source: .phone)
        harness.client.shouldSuspendNextSave = true

        // Call 1 starts pass 1 and suspends inside save() with firstDrink syncVersion 1.
        let call1 = Task {
            await harness.healthSync.reconcile()
        }
        await harness.client.waitForSaveToSuspend()

        // While pass 1 is suspended, edit firstDrink (version -> 1) and trigger overlapping call 2.
        harness.clock.currentNow = logTime.addingTimeInterval(30)
        try harness.logService.edit(
            firstDrink,
            DrinkEdit(hu: Self.dec("1.5"), volumeMl: .set(750), abvPercent: .set(Decimal(5)))
        )
        let call2 = Task {
            await harness.healthSync.reconcile()
        }
        await Task.yield()

        // Arm suspension for pass 2 before releasing pass 1.
        harness.client.shouldSuspendNextSave = true
        harness.client.resumeSuspendedSave()
        await harness.client.waitForSaveToSuspend()

        // While pass 2 (follow-up pass) is suspended, edit firstDrink again (version -> 2),
        // log a second drink, and trigger overlapping call 3.
        harness.clock.currentNow = logTime.addingTimeInterval(60)
        try harness.logService.edit(
            firstDrink,
            DrinkEdit(hu: Decimal(2), volumeMl: .clear, abvPercent: .clear)
        )
        let secondDrink = try harness.logService.log(preset: wine, source: .phone)
        let call3 = Task {
            await harness.healthSync.reconcile()
        }
        await Task.yield()

        harness.client.resumeSuspendedSave()

        let status1 = await call1.value
        let status2 = await call2.value
        let status3 = await call3.value
        #expect(status1 == .upToDate)
        #expect(status2 == .upToDate)
        #expect(status3 == .upToDate)

        #expect(firstDrink.healthSyncedVersion == 2)
        #expect(secondDrink.healthSyncedVersion == 0)
        #expect(harness.client.savedBatches.count == 3)

        let allSamples = harness.client.savedBatches.flatMap { $0 }
        let pairs = allSamples.map { "\($0.syncIdentifier)#\($0.syncVersion)" }
        #expect(pairs.count == Set(pairs).count)
        #expect(
            Set(pairs) == [
                "\(firstDrink.id.uuidString)#1",
                "\(firstDrink.id.uuidString)#2",
                "\(firstDrink.id.uuidString)#3",
                "\(secondDrink.id.uuidString)#1",
            ]
        )
    }
}
