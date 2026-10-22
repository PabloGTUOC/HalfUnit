import Foundation
import SwiftData

public enum BackupCodecError: Error, Equatable, Sendable {
    case unsupportedFormatVersion(Int)
    case invalidDate(String)
}

public struct BackupArchive: Codable, Sendable, Equatable {
    public struct SettingsRecord: Codable, Sendable, Equatable {
        public var dayBoundaryHour: Int
        public var displayUnitRaw: String
        public var firstUseDayKey: Int
        public var healthReadEnabled: Bool
        public var remindersEnabled: Bool
        public var reminderMinutes: Int?
        public var appLockEnabled: Bool
        public var updatedAt: Date

        public init(
            dayBoundaryHour: Int,
            displayUnitRaw: String,
            firstUseDayKey: Int,
            healthReadEnabled: Bool = false,
            remindersEnabled: Bool = false,
            reminderMinutes: Int? = nil,
            appLockEnabled: Bool = false,
            updatedAt: Date
        ) {
            self.dayBoundaryHour = dayBoundaryHour
            self.displayUnitRaw = displayUnitRaw
            self.firstUseDayKey = firstUseDayKey
            self.healthReadEnabled = healthReadEnabled
            self.remindersEnabled = remindersEnabled
            self.reminderMinutes = reminderMinutes
            self.appLockEnabled = appLockEnabled
            self.updatedAt = updatedAt
        }

        public init(settings: AppSettings) {
            self.init(
                dayBoundaryHour: settings.dayBoundaryHour,
                displayUnitRaw: settings.displayUnitRaw,
                firstUseDayKey: settings.firstUseDayKey,
                healthReadEnabled: settings.healthReadEnabled,
                remindersEnabled: settings.remindersEnabled,
                reminderMinutes: settings.reminderMinutes,
                appLockEnabled: settings.appLockEnabled,
                updatedAt: settings.updatedAt
            )
        }
    }

    public struct PresetRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var key: String?
        public var name: String
        public var symbolName: String
        public var huHalfSteps: Int
        public var volumeMl: Int
        public var abvTenths: Int
        public var sortOrder: Int
        public var isHidden: Bool
        public var updatedAt: Date

        public init(
            id: UUID,
            key: String? = nil,
            name: String,
            symbolName: String,
            huHalfSteps: Int,
            volumeMl: Int,
            abvTenths: Int,
            sortOrder: Int,
            isHidden: Bool,
            updatedAt: Date
        ) {
            self.id = id
            self.key = key
            self.name = name
            self.symbolName = symbolName
            self.huHalfSteps = huHalfSteps
            self.volumeMl = volumeMl
            self.abvTenths = abvTenths
            self.sortOrder = sortOrder
            self.isHidden = isHidden
            self.updatedAt = updatedAt
        }

        public init(preset: Preset) {
            self.init(
                id: preset.id,
                key: preset.key,
                name: preset.name,
                symbolName: preset.symbolName,
                huHalfSteps: preset.huHalfSteps,
                volumeMl: preset.volumeMl,
                abvTenths: preset.abvTenths,
                sortOrder: preset.sortOrder,
                isHidden: preset.isHidden,
                updatedAt: preset.updatedAt
            )
        }
    }

    public struct DrinkRecord: Codable, Sendable, Equatable {
        public var id: UUID
        public var timestamp: Date
        public var timeZoneIdentifier: String
        public var logicalDayKey: Int
        public var presetId: UUID?
        public var name: String
        public var huHalfSteps: Int
        public var volumeMl: Int?
        public var abvTenths: Int?
        public var centigrams: Int
        public var note: String?
        public var sourceRaw: String
        public var healthSyncVersion: Int
        public var deletedAt: Date?
        public var createdAt: Date
        public var updatedAt: Date

        public init(
            id: UUID,
            timestamp: Date,
            timeZoneIdentifier: String,
            logicalDayKey: Int,
            presetId: UUID? = nil,
            name: String,
            huHalfSteps: Int,
            volumeMl: Int? = nil,
            abvTenths: Int? = nil,
            centigrams: Int,
            note: String? = nil,
            sourceRaw: String,
            healthSyncVersion: Int,
            deletedAt: Date? = nil,
            createdAt: Date,
            updatedAt: Date
        ) {
            self.id = id
            self.timestamp = timestamp
            self.timeZoneIdentifier = timeZoneIdentifier
            self.logicalDayKey = logicalDayKey
            self.presetId = presetId
            self.name = name
            self.huHalfSteps = huHalfSteps
            self.volumeMl = volumeMl
            self.abvTenths = abvTenths
            self.centigrams = centigrams
            self.note = note
            self.sourceRaw = sourceRaw
            self.healthSyncVersion = healthSyncVersion
            self.deletedAt = deletedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        public init(drink: Drink) {
            self.init(
                id: drink.id,
                timestamp: drink.timestamp,
                timeZoneIdentifier: drink.timeZoneIdentifier,
                logicalDayKey: drink.logicalDayKey,
                presetId: drink.presetId,
                name: drink.name,
                huHalfSteps: drink.huHalfSteps,
                volumeMl: drink.volumeMl,
                abvTenths: drink.abvTenths,
                centigrams: drink.centigrams,
                note: drink.note,
                sourceRaw: drink.sourceRaw,
                healthSyncVersion: drink.healthSyncVersion,
                deletedAt: drink.deletedAt,
                createdAt: drink.createdAt,
                updatedAt: drink.updatedAt
            )
        }

        public func toDrinkTransfer() -> DrinkTransfer {
            DrinkTransfer(
                schema: DrinkTransfer.currentSchema,
                id: id,
                timestamp: timestamp,
                timeZoneIdentifier: timeZoneIdentifier,
                logicalDayKey: logicalDayKey,
                presetId: presetId,
                name: name,
                huHalfSteps: huHalfSteps,
                volumeMl: volumeMl,
                abvTenths: abvTenths,
                centigrams: centigrams,
                note: note,
                sourceRaw: sourceRaw,
                healthSyncVersion: healthSyncVersion,
                deletedAt: deletedAt,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var exportedAt: Date
    public var settings: SettingsRecord
    public var presets: [PresetRecord]
    public var drinks: [DrinkRecord]

    public init(
        formatVersion: Int = BackupArchive.currentFormatVersion,
        exportedAt: Date,
        settings: SettingsRecord,
        presets: [PresetRecord],
        drinks: [DrinkRecord]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.presets = presets
        self.drinks = drinks
    }
}

public enum BackupCodec {
    public static let currentFormatVersion = BackupArchive.currentFormatVersion

    @MainActor
    public static func makeArchive(
        from logService: LogService,
        exportedAt: Date? = nil
    ) throws -> BackupArchive {
        let currentSettings = try logService.settings()
        let allPresets = try logService.presets(includeHidden: true)
        let allDrinks = try logService.drinks(includeDeleted: true)

        return BackupArchive(
            formatVersion: currentFormatVersion,
            exportedAt: exportedAt ?? logService.currentDate(),
            settings: BackupArchive.SettingsRecord(settings: currentSettings),
            presets: allPresets.map(BackupArchive.PresetRecord.init(preset:)),
            drinks: allDrinks.map(BackupArchive.DrinkRecord.init(drink:))
        )
    }

    @MainActor
    public static func export(
        from logService: LogService,
        exportedAt: Date? = nil
    ) throws -> Data {
        let archive = try makeArchive(from: logService, exportedAt: exportedAt)
        return try encode(archive)
    }

    public static func encode(_ archive: BackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatted = Self.formatISO8601(date)
            try container.encode(formatted)
        }
        return try encoder.encode(archive)
    }

    public static func decode(_ data: Data) throws -> BackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = Self.parseISO8601(string) else {
                throw BackupCodecError.invalidDate(string)
            }
            return date
        }
        let archive = try decoder.decode(BackupArchive.self, from: data)
        guard archive.formatVersion == currentFormatVersion else {
            throw BackupCodecError.unsupportedFormatVersion(archive.formatVersion)
        }
        return archive
    }

    @MainActor
    public static func restore(
        from data: Data,
        into context: ModelContext
    ) throws {
        let archive = try decode(data)
        try restore(from: archive, into: context)
    }

    @MainActor
    public static func restore(
        from archive: BackupArchive,
        into context: ModelContext
    ) throws {
        guard archive.formatVersion == currentFormatVersion else {
            throw BackupCodecError.unsupportedFormatVersion(archive.formatVersion)
        }

        // 1. Settings: upsert with last-writer-wins by updatedAt
        let existingSettings = try context.fetch(FetchDescriptor<AppSettings>())
        if let newestSettings = existingSettings.max(by: { $0.updatedAt < $1.updatedAt }) {
            if archive.settings.updatedAt > newestSettings.updatedAt {
                newestSettings.dayBoundaryHour = archive.settings.dayBoundaryHour
                newestSettings.displayUnitRaw = archive.settings.displayUnitRaw
                newestSettings.firstUseDayKey = archive.settings.firstUseDayKey
                newestSettings.healthReadEnabled = archive.settings.healthReadEnabled
                newestSettings.remindersEnabled = archive.settings.remindersEnabled
                newestSettings.reminderMinutes = archive.settings.reminderMinutes
                newestSettings.appLockEnabled = archive.settings.appLockEnabled
                newestSettings.updatedAt = archive.settings.updatedAt
            }
        } else {
            let insertedSettings = AppSettings(
                dayBoundaryHour: archive.settings.dayBoundaryHour,
                displayUnitRaw: archive.settings.displayUnitRaw,
                firstUseDayKey: archive.settings.firstUseDayKey,
                healthReadEnabled: archive.settings.healthReadEnabled,
                remindersEnabled: archive.settings.remindersEnabled,
                reminderMinutes: archive.settings.reminderMinutes,
                appLockEnabled: archive.settings.appLockEnabled,
                updatedAt: archive.settings.updatedAt
            )
            context.insert(insertedSettings)
        }

        // 2. Presets: upsert by id with last-writer-wins by updatedAt
        let existingPresets = try context.fetch(FetchDescriptor<Preset>())
        for record in archive.presets {
            let matching = existingPresets.filter { $0.id == record.id }
            if let currentWinner = matching.max(by: { $0.updatedAt < $1.updatedAt }) {
                if record.updatedAt > currentWinner.updatedAt {
                    currentWinner.key = record.key
                    currentWinner.name = record.name
                    currentWinner.symbolName = record.symbolName
                    currentWinner.huHalfSteps = record.huHalfSteps
                    currentWinner.volumeMl = record.volumeMl
                    currentWinner.abvTenths = record.abvTenths
                    currentWinner.sortOrder = record.sortOrder
                    currentWinner.isHidden = record.isHidden
                    currentWinner.updatedAt = record.updatedAt
                }
            } else {
                let insertedPreset = Preset(
                    id: record.id,
                    key: record.key,
                    name: record.name,
                    symbolName: record.symbolName,
                    huHalfSteps: record.huHalfSteps,
                    volumeMl: record.volumeMl,
                    abvTenths: record.abvTenths,
                    sortOrder: record.sortOrder,
                    isHidden: record.isHidden,
                    updatedAt: record.updatedAt
                )
                context.insert(insertedPreset)
            }
        }

        // 3. Drinks: upsert by id with last-writer-wins by updatedAt via DrinkTransferApplier
        // Never touches healthSyncedVersion.
        let applier = DrinkTransferApplier(context: context)
        for record in archive.drinks {
            _ = try applier.apply(record.toDrinkTransfer())
        }

        try context.save()
    }

    private static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fractionalFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]
        basicFormatter.timeZone = TimeZone(identifier: "UTC")
        return basicFormatter.date(from: string)
    }
}
