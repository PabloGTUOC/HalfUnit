import Foundation
import SwiftData
import Testing

@testable import HalfUnitCore

@Suite("CSVExporter and BackupCodec Tests")
@MainActor
struct ExportAndBackupTests {
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

    private func makeHarness(
        now: Date = ExportAndBackupTests.makeDate(
            year: 2026,
            month: 10,
            day: 22,
            hour: 18,
            minute: 0,
            timeZone: ExportAndBackupTests.berlin
        ),
        timeZone: TimeZone = ExportAndBackupTests.berlin
    ) throws -> TestHarness {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let clock = MutableClock(now: now, timeZone: timeZone)
        let service = LogService(
            context: context,
            now: { clock.currentNow },
            timeZone: { clock.currentTimeZone }
        )
        return TestHarness(container: container, context: context, clock: clock, service: service)
    }

    @Test(
        "CSVExporter produces UTF-8 BOM, CRLF line endings, exact 14 columns, dot decimals, RFC 4180 quoting, and excludes deleted drinks"
    )
    func csvExportFormatQuotingBoundaryAndDeletedExclusion() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 22, hour: 21, minute: 5, timeZone: Self.berlin)
        let harness = try makeHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service

        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))
        let beer = try #require(presets.first(where: { $0.key == "beer" }))

        // 1. Wine glass at 2026-10-22 21:05 Berlin (19.2 g, 1.92 std drinks) with RFC 4180 quoting note (commas, quotes, newline)
        let d1 = try service.log(preset: wine, at: t0, source: .phone)
        try service.edit(
            d1,
            DrinkEdit(
                hu: Self.dec("1.5"),
                note: .set("Dinner, \"Reserve\"\r\nSecond line")
            )
        )

        // 2. Late-night 01:30 drink on Sunday 2026-03-29 (Europe/Berlin spring DST week) -> date 2026-03-29, time 01:30, logical_day 2026-03-28
        let tSpring0130 = Self.makeDate(year: 2026, month: 3, day: 29, hour: 1, minute: 30, timeZone: Self.berlin)
        clock.currentNow = tSpring0130
        let d2 = try service.log(preset: beer, at: tSpring0130, source: .watch)

        // 3. Custom drink logged in America/New_York (no preset_key, no volume/abv)
        clock.currentTimeZone = Self.newYork
        let tNY = Self.makeDate(year: 2026, month: 7, day: 4, hour: 23, minute: 45, timeZone: Self.newYork)
        clock.currentNow = tNY
        let d3 = try service.logCustom(
            name: "House \"Sour\", Large",
            hu: Self.dec("1.5"),
            volumeMl: nil,
            abvPercent: nil,
            at: tNY,
            source: .siri
        )

        // 4. Deleted drink (must be excluded from CSV)
        clock.currentTimeZone = Self.berlin
        let tDeleted = Self.makeDate(year: 2026, month: 10, day: 22, hour: 22, minute: 0, timeZone: Self.berlin)
        clock.currentNow = tDeleted
        let deletedDrink = try service.log(preset: beer, at: tDeleted, source: .phone)
        try service.delete(deletedDrink)

        let data = try CSVExporter.exportData(from: service)
        let bytes = [UInt8](data)
        #expect(bytes.count > 3)
        #expect(Array(bytes.prefix(3)) == [0xEF, 0xBB, 0xBF])

        let csvString = try CSVExporter.exportString(from: service)
        #expect(csvString.hasPrefix("\u{FEFF}"))
        #expect(csvString.hasSuffix("\r\n"))

        let withoutBOM = String(csvString.dropFirst())
        let expectedHeader =
            "date,time,logical_day,name,preset_key,hu,grams,standard_drinks,volume_ml,abv_percent,note,source,time_zone,id"
        #expect(withoutBOM.hasPrefix(expectedHeader + "\r\n"))

        // Deleted drink ID must not appear anywhere in CSV
        #expect(!withoutBOM.contains(deletedDrink.id.uuidString))

        // Verify d1 row (2026-10-22, 21:05, wineGlass, 1.5 HU, 19.2 g, 1.92 std drinks, quoted note)
        let expectedD1Row =
            "2026-10-22,21:05,2026-10-22,wineGlass,wineGlass,1.5,19.2,1.92,200,12,\"Dinner, \"\"Reserve\"\"\r\nSecond line\",phone,Europe/Berlin,\(d1.id.uuidString)"
        #expect(withoutBOM.contains(expectedD1Row + "\r\n"))

        // Verify d3 row (New York local date/time, custom quoted name, empty preset_key/volume/abv)
        let expectedD3Row =
            "2026-07-04,23:45,2026-07-04,\"House \"\"Sour\"\", Large\",,1.5,30,3,,,,siri,America/New_York,\(d3.id.uuidString)"
        #expect(withoutBOM.contains(expectedD3Row + "\r\n"))

        // Verify d2 row (01:30 spring DST: date 2026-03-29, time 01:30, logical_day 2026-03-28)
        let expectedD2Row =
            "2026-03-29,01:30,2026-03-28,beer,beer,1,20,2,500,5,,watch,Europe/Berlin,\(d2.id.uuidString)"
        #expect(withoutBOM.contains(expectedD2Row + "\r\n"))

        // Write synthetic sample CSV to .build/sample.csv
        let sampleDrink1 = Drink(
            id: SyntheticDrinks.makeUUID(1),
            timestamp: Self.makeDate(year: 2026, month: 10, day: 22, hour: 20, minute: 30, timeZone: Self.berlin),
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_022,
            presetId: beer.id,
            name: "Beer",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            note: "After-work pint",
            sourceRaw: DrinkSource.phone.rawValue,
            createdAt: t0,
            updatedAt: t0
        )
        let sampleDrink2 = Drink(
            id: SyntheticDrinks.makeUUID(2),
            timestamp: Self.makeDate(year: 2026, month: 10, day: 22, hour: 1, minute: 30, timeZone: Self.berlin),
            timeZoneIdentifier: "Europe/Berlin",
            logicalDayKey: 20_261_021,
            presetId: wine.id,
            name: "Wine glass",
            huHalfSteps: 2,
            volumeMl: 200,
            abvTenths: 120,
            centigrams: 1920,
            note: "Dinner, \"Reserve\"",
            sourceRaw: DrinkSource.watch.rawValue,
            createdAt: t0,
            updatedAt: t0
        )
        let sampleData = CSVExporter.exportData(
            drinks: [sampleDrink1, sampleDrink2],
            presetKeyById: [beer.id: "beer", wine.id: "wineGlass"]
        )
        let repoRoot = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildDir = repoRoot.appending(path: ".build")
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)
        let sampleCSVURL = buildDir.appending(path: "sample.csv")
        try sampleData.write(to: sampleCSVURL, options: .atomic)
    }

    @Test(
        "BackupCodec round trip into empty container preserves settings, presets, active drinks, and tombstones with nil healthSyncedVersion"
    )
    func backupRoundTripIntoEmptyContainer() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 20, hour: 18, minute: 0, timeZone: Self.berlin)
        let sourceHarness = try makeHarness(now: t0, timeZone: Self.berlin)
        let sourceService = sourceHarness.service
        let sourceClock = sourceHarness.clock

        try sourceService.seedDefaultPresetsIfNeeded()
        try sourceService.changeDayBoundary(to: 5)
        try sourceService.updateDisplayUnit(.germanStandardDrinks)

        let presets = try sourceService.presets()
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        let shot = try #require(presets.first(where: { $0.key == "shot" }))

        sourceClock.currentNow = t0.addingTimeInterval(60)
        try sourceService.updatePreset(
            beer,
            name: "Pilsner",
            symbolName: "mug.fill",
            hu: Decimal(1),
            volumeMl: 400,
            abvPercent: Self.dec("4.8")
        )
        try sourceService.setPresetHidden(shot, true)
        let customPreset = try sourceService.addPreset(
            name: "Cider",
            symbolName: "wineglass",
            hu: Decimal(1),
            volumeMl: 330,
            abvPercent: Self.dec("4.5")
        )

        sourceClock.currentNow = t0.addingTimeInterval(120)
        let liveDrink = try sourceService.log(preset: beer, source: .phone)
        liveDrink.healthSyncedVersion = 0

        sourceClock.currentNow = t0.addingTimeInterval(180)
        let deletedDrink = try sourceService.log(preset: customPreset, source: .watch)
        deletedDrink.healthSyncedVersion = 0
        sourceClock.currentNow = t0.addingTimeInterval(240)
        try sourceService.delete(deletedDrink)

        let exportedAt = t0.addingTimeInterval(300)
        let backupData = try BackupCodec.export(from: sourceService, exportedAt: exportedAt)
        let decodedArchive = try BackupCodec.decode(backupData)
        #expect(decodedArchive.formatVersion == 1)
        #expect(decodedArchive.exportedAt == exportedAt)
        #expect(decodedArchive.presets.count == 7)
        #expect(decodedArchive.drinks.count == 2)

        // Restore into a completely empty container
        let targetHarness = try makeHarness(now: exportedAt, timeZone: Self.berlin)
        try BackupCodec.restore(from: backupData, into: targetHarness.context)

        let targetService = targetHarness.service
        let restoredSettings = try targetService.settings()
        let originalSettings = try sourceService.settings()
        #expect(restoredSettings.dayBoundaryHour == originalSettings.dayBoundaryHour)
        #expect(restoredSettings.displayUnit == originalSettings.displayUnit)
        #expect(restoredSettings.firstUseDayKey == originalSettings.firstUseDayKey)
        #expect(restoredSettings.updatedAt == originalSettings.updatedAt)

        let restoredPresets = try targetService.presets(includeHidden: true)
        let originalPresets = try sourceService.presets(includeHidden: true)
        #expect(restoredPresets.map(\.id) == originalPresets.map(\.id))
        #expect(restoredPresets.map(\.name) == originalPresets.map(\.name))
        #expect(restoredPresets.map(\.isHidden) == originalPresets.map(\.isHidden))
        #expect(restoredPresets.map(\.huHalfSteps) == originalPresets.map(\.huHalfSteps))

        let restoredAllDrinks = try targetService.drinks(includeDeleted: true)
        let originalAllDrinks = try sourceService.drinks(includeDeleted: true)
        #expect(restoredAllDrinks.map(\.id) == originalAllDrinks.map(\.id))
        #expect(restoredAllDrinks.map(\.name) == originalAllDrinks.map(\.name))
        #expect(restoredAllDrinks.map(\.centigrams) == originalAllDrinks.map(\.centigrams))
        #expect(restoredAllDrinks.map(\.deletedAt) == originalAllDrinks.map(\.deletedAt))
        #expect(restoredAllDrinks.map(\.updatedAt) == originalAllDrinks.map(\.updatedAt))
        // Restore never sets healthSyncedVersion
        #expect(restoredAllDrinks.allSatisfy { $0.healthSyncedVersion == nil })
    }

    @Test(
        "BackupCodec restore is idempotent, respects last-writer-wins by updatedAt, and never touches healthSyncedVersion"
    )
    func backupRestoreIdempotentAndLastWriterWins() throws {
        let t0 = Self.makeDate(year: 2026, month: 10, day: 21, hour: 12, minute: 0, timeZone: Self.berlin)
        let harness = try makeHarness(now: t0, timeZone: Self.berlin)
        let clock = harness.clock
        let service = harness.service

        try service.seedDefaultPresetsIfNeeded()
        let beer = try #require(try service.presets().first(where: { $0.key == "beer" }))
        let wine = try #require(try service.presets().first(where: { $0.key == "wineGlass" }))

        let drink1 = try service.log(preset: beer, source: .phone)
        drink1.healthSyncedVersion = 0

        let drink2 = try service.log(preset: wine, source: .phone)
        drink2.healthSyncedVersion = 0

        let backupDataAtT0 = try BackupCodec.export(from: service, exportedAt: t0)

        // 1. Idempotent restore at t0
        try BackupCodec.restore(from: backupDataAtT0, into: harness.context)
        try BackupCodec.restore(from: backupDataAtT0, into: harness.context)
        #expect(try harness.context.fetch(FetchDescriptor<Drink>()).count == 2)
        #expect(try harness.context.fetch(FetchDescriptor<Preset>()).count == 6)
        #expect(drink1.healthSyncedVersion == 0)
        #expect(drink2.healthSyncedVersion == 0)

        // 2. Local data becomes newer at t1 (t0 + 600s)
        let t1 = t0.addingTimeInterval(600)
        clock.currentNow = t1
        try service.updateDisplayUnit(.ukUnits)
        try service.updatePreset(
            beer,
            name: "Local Newer Beer",
            symbolName: "mug.fill",
            hu: Self.dec("1.5"),
            volumeMl: 500,
            abvPercent: Decimal(5)
        )
        try service.edit(drink1, DrinkEdit(note: .set("Local newer note")))
        drink1.healthSyncedVersion = 1

        // Restoring older backup from t0 must NOT overwrite newer local settings, preset, or drink1
        try BackupCodec.restore(from: backupDataAtT0, into: harness.context)
        #expect(try service.settings().displayUnit == .ukUnits)
        #expect(beer.name == "Local Newer Beer")
        #expect(beer.hu == Self.dec("1.5"))
        #expect(drink1.note == "Local newer note")
        #expect(drink1.updatedAt == t1)
        #expect(drink1.healthSyncedVersion == 1)

        // 3. Backup with newer updatedAt (t2 = t0 + 1200s) updates drink2 without touching healthSyncedVersion
        let t2 = t0.addingTimeInterval(1200)
        var archive = try BackupCodec.decode(backupDataAtT0)
        if let index = archive.drinks.firstIndex(where: { $0.id == drink2.id }) {
            archive.drinks[index].note = "Remote newer note"
            archive.drinks[index].healthSyncVersion = 2
            archive.drinks[index].updatedAt = t2
        }
        try BackupCodec.restore(from: archive, into: harness.context)
        #expect(drink2.note == "Remote newer note")
        #expect(drink2.healthSyncVersion == 2)
        #expect(drink2.updatedAt == t2)
        // healthSyncedVersion remains untouched (0) so HealthSync reconcile will pick up version 2 != 0
        #expect(drink2.healthSyncedVersion == 0)

        // 4. Unsupported formatVersion throws
        var badArchive = archive
        badArchive.formatVersion = 99
        let badData = try BackupCodec.encode(badArchive)
        #expect(throws: BackupCodecError.unsupportedFormatVersion(99)) {
            _ = try BackupCodec.decode(badData)
        }
    }
}
