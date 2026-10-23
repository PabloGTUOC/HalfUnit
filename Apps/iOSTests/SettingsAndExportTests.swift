import Foundation
import HalfUnitCore
import SwiftData
import Testing
import UIKit

@testable import HalfUnit

@Suite("Settings and Export iOS Tests")
struct SettingsAndExportTests {
    private static let englishLocale = Locale(identifier: "en_US")
    private static let germanLocale = Locale(identifier: "de_DE")
    private static let berlinTimeZone = TimeZone(identifier: "Europe/Berlin")!
    private static let newYorkTimeZone = TimeZone(identifier: "America/New_York")!

    private static func dec(_ string: String) -> Decimal {
        Decimal(string: string)!
    }

    private static func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
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

    @Test("Curated preset symbols resolve to valid UIImages and localize in English and German")
    func curatedSymbolsAndLocalizations() {
        #expect(!SettingsPresetSymbol.curatedSymbols.isEmpty)
        for symbol in SettingsPresetSymbol.allCases {
            let image: UIImage? =
                PresetPresentation.isCustomSymbol(symbol.rawValue)
                ? UIImage(named: symbol.rawValue)
                : UIImage(systemName: symbol.rawValue)
            #expect(image != nil)
            let enLabel = AppLocalization.string(symbol.accessibilityKey, locale: Self.englishLocale)
            let deLabel = AppLocalization.string(symbol.accessibilityKey, locale: Self.germanLocale)
            #expect(!enLabel.isEmpty)
            #expect(!deLabel.isEmpty)
            #expect(enLabel != symbol.accessibilityKey)
            #expect(deLabel != symbol.accessibilityKey)
        }
    }

    @Test("Presets editor draft: name != key flag-free rule, HU stepper, read-only grams, hide/unhide, and reorder")
    @MainActor
    func presetsEditorRulesAndFlagFreeRename() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Self.makeDate(2026, 10, 22, 18, 0)
        let currentNow = LockSettingsValue(t0)
        let currentZone = LockSettingsValue(Self.berlinTimeZone)

        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )
        try service.seedDefaultPresetsIfNeeded()

        let presets = try service.presets(includeHidden: true)
        let beer = try #require(presets.first(where: { $0.key == "beer" }))
        #expect(beer.name == "beer")

        // When name == key, displayName is localized ("Beer" in EN, "Bier" in DE)
        let itemEn = SettingsPresetItem(preset: beer, locale: Self.englishLocale)
        let itemDe = SettingsPresetItem(preset: beer, locale: Self.germanLocale)
        #expect(itemEn.displayName == "Beer")
        #expect(itemDe.displayName == "Bier")

        // Editing volume/ABV without changing the localized name preserves name == key ("beer")
        var draftUnrenamed = SettingsPresetDraft(item: itemEn, locale: Self.englishLocale)
        #expect(draftUnrenamed.nameText == "Beer")
        draftUnrenamed.stepHU(by: -1)  // 1.0 -> 0.5
        draftUnrenamed.stepHU(by: -5)  // clamps to minimum 0.5 HU
        #expect(draftUnrenamed.hu == Self.dec("0.5"))
        draftUnrenamed.stepHU(by: 2)  // 0.5 -> 1.5 HU
        #expect(draftUnrenamed.hu == Self.dec("1.5"))
        draftUnrenamed.volumeMlText = "400"
        draftUnrenamed.abvPercentText = "5.5"
        // 400 * 5.5% * 0.8 = 17.6 g -> formatted read-only as "18 g"
        #expect(draftUnrenamed.calculatedGrams == Self.dec("17.6"))
        #expect(draftUnrenamed.formattedGramsText(locale: Self.englishLocale) == "18 g")
        #expect(draftUnrenamed.resolvedNameForStorage(locale: Self.englishLocale) == "beer")

        currentNow.setValue(t0.addingTimeInterval(60))
        try service.updatePreset(
            beer,
            name: draftUnrenamed.resolvedNameForStorage(locale: Self.englishLocale),
            symbolName: draftUnrenamed.symbolName,
            hu: draftUnrenamed.hu,
            volumeMl: draftUnrenamed.parsedVolumeMl!,
            abvPercent: draftUnrenamed.parsedAbvPercent!
        )
        #expect(beer.key == "beer")
        #expect(beer.name == "beer")
        #expect(SettingsPresetItem(preset: beer, locale: Self.germanLocale).displayName == "Bier")

        // Now rename default preset to "Augustiner Helles": name != key, so stored name is shown in all locales
        var draftRenamed = SettingsPresetDraft(
            item: SettingsPresetItem(preset: beer, locale: Self.englishLocale),
            locale: Self.englishLocale
        )
        draftRenamed.nameText = "Augustiner Helles"
        draftRenamed.symbolName = SettingsPresetSymbol.mug.rawValue
        #expect(draftRenamed.resolvedNameForStorage(locale: Self.englishLocale) == "Augustiner Helles")

        currentNow.setValue(t0.addingTimeInterval(120))
        try service.updatePreset(
            beer,
            name: draftRenamed.resolvedNameForStorage(locale: Self.englishLocale),
            symbolName: draftRenamed.symbolName,
            hu: draftRenamed.hu,
            volumeMl: draftRenamed.parsedVolumeMl!,
            abvPercent: draftRenamed.parsedAbvPercent!
        )
        #expect(beer.key == "beer")
        #expect(beer.name == "Augustiner Helles")
        #expect(SettingsPresetItem(preset: beer, locale: Self.englishLocale).displayName == "Augustiner Helles")
        #expect(SettingsPresetItem(preset: beer, locale: Self.germanLocale).displayName == "Augustiner Helles")
    }

    @Test(
        "HealthPreferences defaults to ON in UserDefaults, and SettingsActions handles toggle, denied status, and Allow Apple Health"
    )
    @MainActor
    func healthPreferencesAndSettingsActions() async throws {
        let suiteName = "es.opinasdeque.halfunit.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        // Default ON when key is absent
        #expect(HealthPreferences.isSyncEnabled(in: defaults) == true)

        let container = try ModelContainerFactory.make(inMemory: true)
        let nowDate = Self.makeDate(2026, 10, 22, 19, 0)
        let service = LogService(
            context: container.mainContext,
            now: { nowDate },
            timeZone: { Self.berlinTimeZone }
        )
        let healthClient = FakeSettingsHealthClient()
        healthClient.authorization = .denied

        let healthSync = HealthSync(
            context: container.mainContext,
            client: healthClient,
            isEnabled: { HealthPreferences.isSyncEnabled(in: defaults) }
        )

        // When permission is denied, reconcile returns .notAuthorized and Settings shows "Not syncing to Health"
        _ = await healthSync.reconcile()
        let snapshotDeniedEn = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            userDefaults: defaults,
            locale: Self.englishLocale
        )
        #expect(snapshotDeniedEn.isHealthSyncEnabled == true)
        #expect(snapshotDeniedEn.healthStatus == .notAuthorized)
        #expect(snapshotDeniedEn.healthStatusText == "Not syncing to Health")

        let snapshotDeniedDe = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            userDefaults: defaults,
            locale: Self.germanLocale
        )
        #expect(snapshotDeniedDe.healthStatusText == "Keine Synchronisierung mit Health")

        // Turning toggle OFF persists false in UserDefaults and shows "Not syncing to Health"
        let disabledStatus = await SettingsActions.setHealthSyncEnabled(
            false,
            userDefaults: defaults,
            healthSync: healthSync
        )
        #expect(disabledStatus == .disabled)
        #expect(HealthPreferences.isSyncEnabled(in: defaults) == false)

        let snapshotDisabled = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            userDefaults: defaults,
            locale: Self.englishLocale
        )
        #expect(snapshotDisabled.isHealthSyncEnabled == false)
        #expect(snapshotDisabled.healthStatus == .disabled)
        #expect(snapshotDisabled.healthStatusText == "Not syncing to Health")

        // Tapping "Allow Apple Health" enables sync, calls requestAuthorization(), and reconciles
        healthClient.authorizationAfterRequest = .authorized
        let allowedStatus = await SettingsActions.allowAppleHealth(
            userDefaults: defaults,
            healthSync: healthSync
        )
        #expect(healthClient.requestAuthCallCount == 1)
        #expect(allowedStatus == .upToDate)
        #expect(HealthPreferences.isSyncEnabled(in: defaults) == true)

        let snapshotUpToDate = try SettingsScreenSnapshot.load(
            from: service,
            healthSync: healthSync,
            userDefaults: defaults,
            locale: Self.englishLocale
        )
        #expect(snapshotUpToDate.isSyncingToHealth == true)
        #expect(snapshotUpToDate.healthStatusText == "Syncing to Apple Health")
    }

    @Test("Display unit and day boundary changes propagate to TodayScreenSnapshot, Insights, and History")
    @MainActor
    func displayUnitAndBoundaryPropagation() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        // Sunday 2026-03-29 01:30 in Europe/Berlin (spring DST day)
        let t0130 = Self.makeDate(2026, 3, 29, 1, 30, in: Self.berlinTimeZone)
        let currentNow = LockSettingsValue(t0130)
        let currentZone = LockSettingsValue(Self.berlinTimeZone)

        let service = LogService(
            context: container.mainContext,
            now: { currentNow.value },
            timeZone: { currentZone.value }
        )
        try service.seedDefaultPresetsIfNeeded()
        let wine = try #require(try service.presets().first(where: { $0.key == "wineGlass" }))

        // Log 1 wine glass (1 HU, 19.2 g) at 01:30 on 2026-03-29 (logical day 2026-03-28 at boundary 07:00)
        let drink = try service.log(preset: wine, at: t0130, source: .phone)
        #expect(drink.logicalDay == LogicalDay(year: 2026, month: 3, day: 28))

        // Log a second drink in America/New_York on 2026-03-20 at 02:30 NY time
        let tNY0230 = Self.makeDate(2026, 3, 20, 2, 30, in: Self.newYorkTimeZone)
        currentZone.setValue(Self.newYorkTimeZone)
        currentNow.setValue(tNY0230)
        let nyDrink = try service.log(preset: wine, at: tNY0230, source: .phone)
        #expect(nyDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 19))

        // Return clock to Berlin at 2026-03-29 12:00 (logical day 2026-03-29)
        currentZone.setValue(Self.berlinTimeZone)
        currentNow.setValue(Self.makeDate(2026, 3, 29, 12, 0, in: Self.berlinTimeZone))

        // At boundary 07:00, the 01:30 drink belongs to yesterday (2026-03-28), so today's drinks are empty
        let todayBefore = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(todayBefore.todayDrinks.isEmpty)

        // Change boundary to 01:00 -> 01:30 Berlin drink moves to 2026-03-29 (today!), and 02:30 NY drink moves to 2026-03-20
        try service.changeDayBoundary(to: 1)
        #expect(drink.logicalDay == LogicalDay(year: 2026, month: 3, day: 29))
        #expect(nyDrink.logicalDay == LogicalDay(year: 2026, month: 3, day: 20))

        // Verify TodayScreenSnapshot totals in all 4 display units
        let todayHU = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        #expect(todayHU.todayDrinks.count == 1)
        #expect(todayHU.todayTotalText == "Total: 1 HU")
        #expect(todayHU.todayDrinks.first?.huText == "1 HU")

        try service.updateDisplayUnit(.grams)
        let todayGrams = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        // 19.2 g rounds to 19 g for display
        #expect(todayGrams.todayTotalText == "Total: 19 g")
        #expect(todayGrams.todayDrinks.first?.huText == "19 g")

        try service.updateDisplayUnit(.germanStandardDrinks)
        let todayStdEn = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        // 19.2 g / 10 = 1.92 -> 1.9 std. drinks
        #expect(todayStdEn.todayTotalText == "Total: 1.9 std. drinks")
        let todayStdDe = try TodayScreenSnapshot.load(from: service, locale: Self.germanLocale)
        #expect(todayStdDe.todayTotalText == "Gesamt: 1,9 Std.-Getränke")

        try service.updateDisplayUnit(.ukUnits)
        let todayUK = try TodayScreenSnapshot.load(from: service, locale: Self.englishLocale)
        // 19.2 g / 8 = 2.4 UK units
        #expect(todayUK.todayTotalText == "Total: 2.4 UK units")
    }

    @Test("SettingsActions.restoreBackup merges archive, deduplicates drinks, and reconciles with Apple Health")
    @MainActor
    func restoreBackupDeduplicatesAndReconcilesHealth() async throws {
        let t0 = Self.makeDate(2026, 10, 22, 20, 0)
        let sourceContainer = try ModelContainerFactory.make(inMemory: true)
        let sourceService = LogService(
            context: sourceContainer.mainContext,
            now: { t0 },
            timeZone: { Self.berlinTimeZone }
        )
        try sourceService.seedDefaultPresetsIfNeeded()
        let beer = try #require(try sourceService.presets().first(where: { $0.key == "beer" }))
        let exportedDrink = try sourceService.log(preset: beer, source: .phone)
        let backupData = try BackupCodec.export(from: sourceService, exportedAt: t0)

        // Target container has a duplicate row for exportedDrink plus HealthSync enabled
        let targetContainer = try ModelContainerFactory.make(inMemory: true)
        let targetService = LogService(
            context: targetContainer.mainContext,
            now: { t0 },
            timeZone: { Self.berlinTimeZone }
        )
        let healthClient = FakeSettingsHealthClient()
        healthClient.authorization = .authorized
        let healthSync = HealthSync(
            context: targetContainer.mainContext,
            client: healthClient,
            isEnabled: { true }
        )

        // Insert two duplicate rows with older updatedAt to verify dedupeDrinks() runs during restoreBackup
        let olderTime = t0.addingTimeInterval(-120)
        let dup1 = Drink(
            id: exportedDrink.id,
            timestamp: exportedDrink.timestamp,
            timeZoneIdentifier: exportedDrink.timeZoneIdentifier,
            logicalDayKey: exportedDrink.logicalDayKey,
            presetId: exportedDrink.presetId,
            name: "beer",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            sourceRaw: DrinkSource.phone.rawValue,
            createdAt: olderTime,
            updatedAt: olderTime
        )
        let dup2 = Drink(
            id: exportedDrink.id,
            timestamp: exportedDrink.timestamp,
            timeZoneIdentifier: exportedDrink.timeZoneIdentifier,
            logicalDayKey: exportedDrink.logicalDayKey,
            presetId: exportedDrink.presetId,
            name: "beer",
            huHalfSteps: 2,
            volumeMl: 500,
            abvTenths: 50,
            centigrams: 2000,
            sourceRaw: DrinkSource.phone.rawValue,
            createdAt: olderTime,
            updatedAt: olderTime
        )
        targetContainer.mainContext.insert(dup1)
        targetContainer.mainContext.insert(dup2)
        try targetContainer.mainContext.save()

        try await SettingsActions.restoreBackup(
            from: backupData,
            into: targetContainer.mainContext,
            logService: targetService,
            healthSync: healthSync
        )

        // Deduplicated to 1 row in SwiftData AND synced to Apple Health
        let allStoredDrinks = try targetContainer.mainContext.fetch(FetchDescriptor<Drink>())
        #expect(allStoredDrinks.count == 1)
        #expect(allStoredDrinks.first?.updatedAt == t0)
        #expect(allStoredDrinks.first?.healthSyncedVersion == 0)
        #expect(healthClient.savedSamples.count == 1)
        #expect(healthClient.savedSamples.first?.syncIdentifier == exportedDrink.id.uuidString)
    }

    @Test("Export filenames, About URLs, and all Settings strings localize in English and German")
    func filenamesAboutLinksAndLocalizations() {
        let day = LogicalDay(year: 2026, month: 10, day: 22)
        #expect(SettingsScreenSnapshot.csvDefaultFilename(for: day) == "HalfUnit-drinks-2026-10-22.csv")
        #expect(SettingsScreenSnapshot.backupDefaultFilename(for: day) == "HalfUnit-backup-2026-10-22.json")
        #expect(SettingsAboutLinks.germanyURL.absoluteString == "https://www.kenn-dein-limit.de")
        #expect(SettingsAboutLinks.ukURL.absoluteString == "https://www.nhs.uk/live-well/alcohol-advice/")

        let requiredKeys = [
            "settings.about.guidanceNote",
            "settings.about.link.germany",
            "settings.about.link.uk",
            "settings.about.privacy",
            "settings.about.version",
            "settings.data.backupJSON",
            "settings.data.exportCSV",
            "settings.data.footer",
            "settings.data.restore",
            "settings.data.restore.confirm.action",
            "settings.data.restore.confirm.message",
            "settings.data.restore.confirm.title",
            "settings.data.restore.failed",
            "settings.data.restore.success",
            "settings.dayBoundary.footer",
            "settings.dayBoundary.label",
            "settings.displayUnit.footer",
            "settings.displayUnit.germanStandardDrinks",
            "settings.displayUnit.grams",
            "settings.displayUnit.hu",
            "settings.displayUnit.label",
            "settings.displayUnit.ukUnits",
            "settings.health.allow",
            "settings.health.footer",
            "settings.health.status.label",
            "settings.health.status.notSyncing",
            "settings.health.status.syncing",
            "settings.health.toggle",
            "settings.preset.abv",
            "settings.preset.add.title",
            "settings.preset.edit.title",
            "settings.preset.grams",
            "settings.preset.hidden",
            "settings.preset.hu",
            "settings.preset.name",
            "settings.preset.name.placeholder",
            "settings.preset.symbol",
            "settings.preset.volume",
            "settings.presets.add",
            "settings.presets.footer",
            "settings.presets.hiddenBadge",
            "settings.presets.hide.accessibility",
            "settings.presets.row.accessibility",
            "settings.presets.unhide.accessibility",
            "settings.section.about",
            "settings.section.data",
            "settings.section.dayBoundary",
            "settings.section.displayUnit",
            "settings.section.health",
            "settings.section.presets",
        ]

        for key in requiredKeys {
            let en = AppLocalization.string(key, locale: Self.englishLocale)
            let de = AppLocalization.string(key, locale: Self.germanLocale)
            #expect(!en.isEmpty, "Missing English localization for \(key)")
            #expect(!de.isEmpty, "Missing German localization for \(key)")
            #expect(en != key, "Untranslated English key \(key)")
            #expect(de != key, "Untranslated German key \(key)")
        }

        #expect(
            AppLocalization.string("settings.about.privacy", locale: Self.englishLocale)
                == "Your data stays on your devices and in your iCloud."
        )
    }

    @Test(
        "CSV export from Settings uses PresetPresentation to localize names in en and de and escapes formula injection"
    )
    @MainActor
    func csvExportLocalizedNamesAndFormulaInjection() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let t0 = Self.makeDate(2026, 10, 22, 19, 0)
        let service = LogService(
            context: container.mainContext,
            now: { t0 },
            timeZone: { Self.berlinTimeZone }
        )
        try service.seedDefaultPresetsIfNeeded()
        let presets = try service.presets()
        let wine = try #require(presets.first(where: { $0.key == "wineGlass" }))

        _ = try service.log(preset: wine, at: t0, source: .phone)

        // Custom drink with formula injection characters in name and note
        let t1 = Self.makeDate(2026, 10, 22, 19, 30)
        let formulaDrink = try service.logCustom(
            name: "=SUM(1,2)",
            hu: Decimal(1),
            volumeMl: 500,
            abvPercent: Decimal(5),
            at: t1,
            source: .phone
        )
        try service.edit(formulaDrink, DrinkEdit(note: .set("+DangerousFormula")))

        // English export
        let enData = try CSVExporter.exportData(from: service) { presetKey, storedName in
            PresetPresentation.localizedName(presetKey: presetKey, fallbackName: storedName, locale: Self.englishLocale)
        }
        let enString = String(decoding: enData, as: UTF8.self)
        #expect(enString.contains(",Wine glass,wineGlass,1,19.2,1.92,"))
        #expect(enString.contains("\"'=SUM(1,2)\",,1,20,2,500,5,'+DangerousFormula,phone"))

        // German export
        let deData = try CSVExporter.exportData(from: service) { presetKey, storedName in
            PresetPresentation.localizedName(presetKey: presetKey, fallbackName: storedName, locale: Self.germanLocale)
        }
        let deString = String(decoding: deData, as: UTF8.self)
        #expect(deString.contains(",Glas Wein,wineGlass,1,19.2,1.92,"))
        #expect(deString.contains("\"'=SUM(1,2)\",,1,20,2,500,5,'+DangerousFormula,phone"))
    }
}

private final class LockSettingsValue<Value: Sendable>: @unchecked Sendable {
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

private final class FakeSettingsHealthClient: HealthStoreClient, @unchecked Sendable {
    var isAvailable = true
    var authorization: HealthWriteAuthorization = .authorized
    var authorizationAfterRequest: HealthWriteAuthorization = .authorized
    private(set) var requestAuthCallCount = 0
    private(set) var savedSamples: [HealthDrinkSample] = []
    private(set) var deletedIdentifiers: [String] = []

    func writeAuthorization() async -> HealthWriteAuthorization {
        guard isAvailable else {
            return .unavailable
        }
        return authorization
    }

    func requestWriteAuthorization() async throws {
        requestAuthCallCount += 1
        authorization = authorizationAfterRequest
    }

    func save(_ samples: [HealthDrinkSample]) async throws {
        savedSamples.append(contentsOf: samples)
    }

    func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
        deletedIdentifiers.append(contentsOf: ids)
    }
}
