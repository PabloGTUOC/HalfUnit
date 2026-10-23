import Foundation
import HalfUnitCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

enum SettingsPresetSymbol: String, CaseIterable, Identifiable, Sendable {
    case beerBottle = "halfunit.beer.bottle"
    case beerMug = "halfunit.beer.mug"
    case wineSmall = "halfunit.wine.small"
    case wineGlass = "halfunit.wine.glass"
    case shot = "halfunit.shot"
    case longDrink = "halfunit.longdrink"
    case wineglass = "wineglass"
    case mug = "mug"
    case waterbottle = "waterbottle"

    var id: String { rawValue }

    static var curatedSymbols: [String] {
        allCases.map(\.rawValue)
    }

    var isCustom: Bool {
        rawValue.hasPrefix("halfunit.")
    }

    var accessibilityKey: String {
        switch self {
        case .beerBottle:
            return "settings.preset.symbol.halfunit.beer.bottle"
        case .beerMug:
            return "settings.preset.symbol.halfunit.beer.mug"
        case .wineSmall:
            return "settings.preset.symbol.halfunit.wine.small"
        case .wineGlass:
            return "settings.preset.symbol.halfunit.wine.glass"
        case .shot:
            return "settings.preset.symbol.halfunit.shot"
        case .longDrink:
            return "settings.preset.symbol.halfunit.longdrink"
        case .wineglass:
            return "settings.preset.symbol.wineglass"
        case .mug:
            return "settings.preset.symbol.mug"
        case .waterbottle:
            return "settings.preset.symbol.waterbottle"
        }
    }
}

struct SettingsPresetItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let key: String?
    let storedName: String
    let displayName: String
    let symbolName: String
    let hu: Decimal
    let volumeMl: Int
    let abvPercent: Decimal
    let grams: Decimal
    let sortOrder: Int
    let isHidden: Bool
    let summaryText: String

    init(preset: Preset, locale: Locale = .current) {
        self.id = preset.id
        self.key = preset.key
        self.storedName = preset.name
        self.displayName = Self.resolveDisplayName(
            key: preset.key,
            storedName: preset.name,
            locale: locale
        )
        self.symbolName = Self.resolveSymbolName(
            key: preset.key,
            storedSymbol: preset.symbolName
        )
        self.hu = preset.hu
        self.volumeMl = preset.volumeMl
        self.abvPercent = preset.abvPercent
        self.grams = preset.grams
        self.sortOrder = preset.sortOrder
        self.isHidden = preset.isHidden

        let huText = PresetPresentation.formattedHU(preset.hu, locale: locale)
        let volumeText = String(
            format: AppLocalization.string("unit.mlValue", locale: locale),
            locale: locale,
            Int64(preset.volumeMl)
        )
        let abvNumber = PresetPresentation.formattedHUNumber(preset.abvPercent, locale: locale)
        let abvText = String(
            format: AppLocalization.string("unit.abvValue", locale: locale),
            locale: locale,
            abvNumber
        )
        let gramsText = AmountFormatting.formattedGrams(preset.grams, locale: locale)
        self.summaryText = "\(huText) · \(volumeText) · \(abvText) · \(gramsText)"
    }

    static func resolveDisplayName(
        key: String?,
        storedName: String,
        locale: Locale = .current
    ) -> String {
        if let key {
            if storedName != key {
                return storedName
            }
            return PresetPresentation.localizedName(
                presetKey: key,
                fallbackName: storedName,
                locale: locale
            )
        }
        return storedName
    }

    static func resolveSymbolName(
        key: String?,
        storedSymbol: String
    ) -> String {
        let trimmed = storedSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if let key,
                let defaultDef = DefaultPresets.all.first(where: { $0.key == key }),
                trimmed == defaultDef.symbolName
            {
                return PresetPresentation.symbolName(presetKey: key, fallbackSymbol: trimmed)
            }
            return trimmed
        }
        return PresetPresentation.symbolName(presetKey: key, fallbackSymbol: "wineglass")
    }
}

struct SettingsPresetDraft: Equatable, Sendable {
    let presetId: UUID?
    let presetKey: String?
    let originalStoredName: String?

    var nameText: String
    var symbolName: String
    var huHalfSteps: Int
    var volumeMlText: String
    var abvPercentText: String
    var isHidden: Bool

    init(locale: Locale = .current) {
        self.presetId = nil
        self.presetKey = nil
        self.originalStoredName = nil
        self.nameText = ""
        self.symbolName = SettingsPresetSymbol.mug.rawValue
        self.huHalfSteps = 2
        self.volumeMlText = "500"
        self.abvPercentText = Self.formatDecimal(Decimal(5), locale: locale)
        self.isHidden = false
    }

    init(item: SettingsPresetItem, locale: Locale = .current) {
        self.presetId = item.id
        self.presetKey = item.key
        self.originalStoredName = item.storedName
        self.nameText = item.displayName
        self.symbolName = item.symbolName
        self.huHalfSteps = Self.halfSteps(from: item.hu)
        self.volumeMlText = String(item.volumeMl)
        self.abvPercentText = Self.formatDecimal(item.abvPercent, locale: locale)
        self.isHidden = item.isHidden
    }

    var hu: Decimal {
        let clamped = max(1, huHalfSteps)
        return Decimal(
            sign: .plus,
            exponent: -1,
            significand: Decimal(clamped) * Decimal(5)
        )
    }

    mutating func stepHU(by deltaHalfSteps: Int) {
        huHalfSteps = max(1, huHalfSteps + deltaHalfSteps)
    }

    var parsedVolumeMl: Int? {
        let trimmed = volumeMlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            return nil
        }
        return value
    }

    var parsedAbvPercent: Decimal? {
        let trimmed = abvPercentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized), !value.isNaN, value > Decimal(0) else {
            return nil
        }
        return value
    }

    var calculatedGrams: Decimal {
        guard let volumeMl = parsedVolumeMl, let abv = parsedAbvPercent else {
            return Decimal(0)
        }
        return Units.grams(volumeMl: volumeMl, abvPercent: abv)
    }

    func formattedGramsText(locale: Locale = .current) -> String {
        AmountFormatting.formattedGrams(calculatedGrams, locale: locale)
    }

    var isValid: Bool {
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && Units.isValidHU(hu)
            && parsedVolumeMl != nil
            && parsedAbvPercent != nil
    }

    func resolvedNameForStorage(locale: Locale = .current) -> String {
        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let key = presetKey {
            let localizedDefault = PresetPresentation.localizedName(
                presetKey: key,
                fallbackName: key,
                locale: locale
            )
            if trimmed == localizedDefault || trimmed == key {
                return key
            }
        }
        return trimmed
    }

    private static func halfSteps(from hu: Decimal) -> Int {
        var scaled = hu * Decimal(2)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return max(1, NSDecimalNumber(decimal: rounded).intValue)
    }

    private static func formatDecimal(_ value: Decimal, locale: Locale) -> String {
        value.formatted(
            .number
                .locale(locale)
                .precision(.fractionLength(0...1))
        )
    }
}

struct SettingsAboutLinks {
    static let germanyURL = URL(string: "https://www.kenn-dein-limit.de")!
    static let ukURL = URL(string: "https://www.nhs.uk/live-well/alcohol-advice/")!
}

struct SettingsScreenSnapshot: Equatable, Sendable {
    let presets: [SettingsPresetItem]
    let dayBoundaryHour: Int
    let displayUnit: DisplayUnit
    let isHealthSyncEnabled: Bool
    let healthStatus: HealthSync.Status
    let healthStatusText: String
    let isSyncingToHealth: Bool
    let todayDay: LogicalDay
    let appVersionText: String
    let remindersEnabled: Bool
    let reminderMinutes: Int
    let appLockEnabled: Bool
    let isAppLockAvailable: Bool

    @MainActor
    static func load(
        from logService: LogService,
        healthSync: HealthSync,
        userDefaults: UserDefaults = HealthPreferences.appGroupUserDefaults,
        authenticator: any AppLockAuthenticator = SystemAppLockAuthenticator.shared,
        bundle: Bundle = .main,
        locale: Locale = .current
    ) throws -> SettingsScreenSnapshot {
        try logService.seedDefaultPresetsIfNeeded()
        let settings = try logService.settings()
        let rawPresets = try logService.presets(includeHidden: true)
        let presetItems = rawPresets.map { SettingsPresetItem(preset: $0, locale: locale) }

        let syncEnabled = HealthPreferences.isSyncEnabled(in: userDefaults)
        let effectiveStatus: HealthSync.Status = syncEnabled ? healthSync.lastStatus : .disabled
        let statusText = Self.formatHealthStatus(effectiveStatus, locale: locale)
        let isSyncing = (effectiveStatus == .upToDate)

        let todayDay = try logService.today()
        let version =
            (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "1.0"

        let remindersEnabled = settings.remindersEnabled
        let reminderMinutes = settings.reminderMinutes ?? ReminderScheduler.defaultReminderMinutes
        let appLockEnabled = settings.appLockEnabled
        let isAppLockAvailable = authenticator.canAuthenticate()

        return SettingsScreenSnapshot(
            presets: presetItems,
            dayBoundaryHour: settings.dayBoundaryHour,
            displayUnit: settings.displayUnit,
            isHealthSyncEnabled: syncEnabled,
            healthStatus: effectiveStatus,
            healthStatusText: statusText,
            isSyncingToHealth: isSyncing,
            todayDay: todayDay,
            appVersionText: version,
            remindersEnabled: remindersEnabled,
            reminderMinutes: reminderMinutes,
            appLockEnabled: appLockEnabled,
            isAppLockAvailable: isAppLockAvailable
        )
    }

    static func formatHealthStatus(
        _ status: HealthSync.Status,
        locale: Locale = .current
    ) -> String {
        switch status {
        case .upToDate:
            return AppLocalization.string("settings.health.status.syncing", locale: locale)
        case .disabled, .unavailable, .notAuthorized, .failed:
            return AppLocalization.string("settings.health.status.notSyncing", locale: locale)
        }
    }

    static func formatBoundaryHour(_ hour: Int, locale: Locale = .current) -> String {
        let clamped = min(max(0, hour), 23)
        return String(format: "%02d:00", locale: locale, clamped)
    }

    static func displayUnitLabelKey(for unit: DisplayUnit) -> String {
        switch unit {
        case .hu:
            return "settings.displayUnit.hu"
        case .grams:
            return "settings.displayUnit.grams"
        case .germanStandardDrinks:
            return "settings.displayUnit.germanStandardDrinks"
        case .ukUnits:
            return "settings.displayUnit.ukUnits"
        }
    }

    static func csvDefaultFilename(for day: LogicalDay) -> String {
        let datePart = CSVExporter.formatLogicalDay(day)
        return "HalfUnit-drinks-\(datePart).csv"
    }

    static func backupDefaultFilename(for day: LogicalDay) -> String {
        let datePart = CSVExporter.formatLogicalDay(day)
        return "HalfUnit-backup-\(datePart).json"
    }
}

@MainActor
enum SettingsActions {
    static func setHealthSyncEnabled(
        _ isEnabled: Bool,
        userDefaults: UserDefaults = HealthPreferences.appGroupUserDefaults,
        healthSync: HealthSync
    ) async -> HealthSync.Status {
        HealthPreferences.setSyncEnabled(isEnabled, in: userDefaults)
        await HalfUnitApp.reconcileHealth(healthSync: healthSync)
        return healthSync.lastStatus
    }

    static func allowAppleHealth(
        userDefaults: UserDefaults = HealthPreferences.appGroupUserDefaults,
        healthSync: HealthSync
    ) async -> HealthSync.Status {
        if !HealthPreferences.isSyncEnabled(in: userDefaults) {
            HealthPreferences.setSyncEnabled(true, in: userDefaults)
        }
        _ = await healthSync.requestAuthorization()
        await HalfUnitApp.reconcileHealth(healthSync: healthSync)
        return healthSync.lastStatus
    }

    static func setRemindersEnabled(
        _ isEnabled: Bool,
        minutes: Int?,
        logService: LogService,
        reminderScheduler: ReminderScheduler,
        locale: Locale = .current
    ) async -> ReminderScheduleResult {
        let result: ReminderScheduleResult
        if isEnabled {
            let targetMinutes = minutes ?? ReminderScheduler.defaultReminderMinutes
            result = await reminderScheduler.enable(minutes: targetMinutes, locale: locale)
            if result == .scheduled {
                if let settings = try? logService.settings() {
                    settings.remindersEnabled = true
                    settings.reminderMinutes = targetMinutes
                    settings.updatedAt = logService.currentDate()
                    try? settings.modelContext?.save()
                }
            } else {
                if let settings = try? logService.settings() {
                    settings.remindersEnabled = false
                    settings.updatedAt = logService.currentDate()
                    try? settings.modelContext?.save()
                }
            }
        } else {
            await reminderScheduler.disable()
            result = .scheduled
            if let settings = try? logService.settings() {
                settings.remindersEnabled = false
                settings.updatedAt = logService.currentDate()
                try? settings.modelContext?.save()
            }
        }
        return result
    }

    static func setReminderTime(
        minutes: Int,
        logService: LogService,
        reminderScheduler: ReminderScheduler,
        locale: Locale = .current
    ) async throws {
        let settings = try logService.settings()
        settings.reminderMinutes = minutes
        settings.updatedAt = logService.currentDate()
        try settings.modelContext?.save()
        if settings.remindersEnabled {
            try await reminderScheduler.scheduleNotification(minutes: minutes, locale: locale)
        }
    }

    static func setAppLockEnabled(
        _ isEnabled: Bool,
        logService: LogService,
        stateMachine: AppLockStateMachine,
        authReason: String
    ) async -> AppLockStateMachine.EnableResult {
        if isEnabled {
            let result = await stateMachine.requestEnable(reason: authReason)
            if result == .enabled {
                if let settings = try? logService.settings() {
                    settings.appLockEnabled = true
                    settings.updatedAt = logService.currentDate()
                    try? settings.modelContext?.save()
                }
            } else {
                if let settings = try? logService.settings() {
                    settings.appLockEnabled = false
                    settings.updatedAt = logService.currentDate()
                    try? settings.modelContext?.save()
                }
            }
            return result
        } else {
            stateMachine.disable()
            if let settings = try? logService.settings() {
                settings.appLockEnabled = false
                settings.updatedAt = logService.currentDate()
                try? settings.modelContext?.save()
            }
            return .enabled
        }
    }

    static func restoreBackup(
        from data: Data,
        into context: ModelContext,
        logService: LogService,
        healthSync: HealthSync
    ) async throws {
        try BackupCodec.restore(from: data, into: context)
        _ = try logService.dedupeDrinks()
        WidgetCenter.shared.reloadAllTimelines()
        await HalfUnitApp.reconcileHealth(healthSync: healthSync)
    }
}

struct ExportDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json, .plainText] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
