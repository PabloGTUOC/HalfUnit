import Foundation
import SwiftData

public enum LogServiceError: Error, Equatable, Sendable {
    case invalidHU
    case drinkIsDeleted
}

/// Describes a partial update to a `Drink`.
///
/// Non-nullable fields (`timestamp`, `name`, `hu`) use standard optionals where `nil` means "leave unchanged".
/// Nullable fields (`volumeMl`, `abvPercent`, `note`) use the nested `NullableField` enum
/// (`.unchanged`, `.set(Value)`, `.clear`) so callers can explicitly distinguish between leaving a value
/// untouched and clearing it to `nil`.
public struct DrinkEdit: Sendable, Equatable {
    public enum NullableField<Value: Sendable & Equatable>: Sendable, Equatable {
        case unchanged
        case set(Value)
        case clear
    }

    public var timestamp: Date?
    public var presetId: UUID?
    public var name: String?
    public var hu: Decimal?
    public var volumeMl: NullableField<Int>
    public var abvPercent: NullableField<Decimal>
    public var note: NullableField<String>

    public init(
        timestamp: Date? = nil,
        preset: Preset? = nil,
        presetId: UUID? = nil,
        name: String? = nil,
        hu: Decimal? = nil,
        volumeMl: NullableField<Int> = .unchanged,
        abvPercent: NullableField<Decimal> = .unchanged,
        note: NullableField<String> = .unchanged
    ) {
        self.timestamp = timestamp
        self.presetId = preset?.id ?? presetId
        self.name = name
        self.hu = hu
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
        self.note = note
    }
}

@MainActor
public final class LogService {
    private static let tombstoneRetentionSeconds: TimeInterval = 30 * 86_400

    private let context: ModelContext
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone

    public init(
        context: ModelContext,
        now: @escaping @Sendable () -> Date,
        timeZone: @escaping @Sendable () -> TimeZone
    ) {
        self.context = context
        self.now = now
        self.timeZone = timeZone
    }

    public func settings() throws -> AppSettings {
        let allSettings = try context.fetch(FetchDescriptor<AppSettings>())
        if let newest = allSettings.max(by: { $0.updatedAt < $1.updatedAt }) {
            return newest
        }

        let currentNow = now()
        let currentZone = timeZone()
        let firstUseDay = LogicalDay.of(
            currentNow,
            boundaryHour: LogicalDay.defaultBoundaryHour,
            timeZone: currentZone
        )
        let created = AppSettings(
            dayBoundaryHour: LogicalDay.defaultBoundaryHour,
            displayUnitRaw: DisplayUnit.hu.rawValue,
            firstUseDayKey: firstUseDay.key,
            healthReadEnabled: false,
            remindersEnabled: false,
            reminderMinutes: nil,
            appLockEnabled: false,
            updatedAt: currentNow
        )
        context.insert(created)
        try context.save()
        return created
    }

    public func today() throws -> LogicalDay {
        let currentSettings = try settings()
        let boundary = resolvedBoundaryHour(from: currentSettings)
        return LogicalDay.of(now(), boundaryHour: boundary, timeZone: timeZone())
    }

    public func seedDefaultPresetsIfNeeded() throws {
        let existingPresets = try context.fetch(FetchDescriptor<Preset>())
        let existingKeys = Set(existingPresets.compactMap(\.key))
        let currentNow = now()
        var insertedAny = false

        for (index, definition) in DefaultPresets.all.enumerated() where !existingKeys.contains(definition.key) {
            let preset = Preset(
                id: UUID(),
                key: definition.key,
                name: definition.key,
                symbolName: definition.symbolName,
                huHalfSteps: IntegerStorageConversion.huToHalfSteps(definition.hu),
                volumeMl: definition.volumeMl,
                abvTenths: IntegerStorageConversion.abvToTenths(definition.abvPercent),
                sortOrder: index,
                isHidden: false,
                updatedAt: currentNow
            )
            context.insert(preset)
            insertedAny = true
        }

        if insertedAny {
            try context.save()
        }
    }

    public func presets() throws -> [Preset] {
        let allPresets = try context.fetch(FetchDescriptor<Preset>())
        var keyedByKey: [String: Preset] = [:]
        var customPresets: [Preset] = []

        for preset in allPresets {
            if let key = preset.key {
                if let current = keyedByKey[key] {
                    if preset.updatedAt > current.updatedAt
                        || (preset.updatedAt == current.updatedAt && !preset.isHidden && current.isHidden)
                    {
                        keyedByKey[key] = preset
                    }
                } else {
                    keyedByKey[key] = preset
                }
            } else {
                customPresets.append(preset)
            }
        }

        let combined = Array(keyedByKey.values) + customPresets
        return
            combined
            .filter { !$0.isHidden }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                if lhs.name != rhs.name {
                    return lhs.name < rhs.name
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    @discardableResult
    public func log(
        preset: Preset,
        at timestamp: Date? = nil,
        source: DrinkSource
    ) throws -> Drink {
        let currentSettings = try settings()
        let currentNow = now()
        let drinkTimestamp = timestamp ?? currentNow
        let currentZone = timeZone()
        let boundary = resolvedBoundaryHour(from: currentSettings)
        let logicalDay = LogicalDay.of(drinkTimestamp, boundaryHour: boundary, timeZone: currentZone)
        let grams = Units.grams(volumeMl: preset.volumeMl, abvPercent: preset.abvPercent)

        let drink = Drink(
            id: UUID(),
            timestamp: drinkTimestamp,
            timeZoneIdentifier: currentZone.identifier,
            logicalDayKey: logicalDay.key,
            presetId: preset.id,
            name: preset.name,
            huHalfSteps: preset.huHalfSteps,
            volumeMl: preset.volumeMl,
            abvTenths: preset.abvTenths,
            centigrams: IntegerStorageConversion.gramsToCentigrams(grams),
            note: nil,
            sourceRaw: source.rawValue,
            healthSyncVersion: 0,
            deletedAt: nil,
            createdAt: currentNow,
            updatedAt: currentNow
        )
        context.insert(drink)
        try context.save()
        return drink
    }

    @discardableResult
    public func logCustom(
        name: String,
        hu: Decimal,
        volumeMl: Int? = nil,
        abvPercent: Decimal? = nil,
        at timestamp: Date? = nil,
        source: DrinkSource
    ) throws -> Drink {
        guard Units.isValidHU(hu) else {
            throw LogServiceError.invalidHU
        }

        let currentSettings = try settings()
        let currentNow = now()
        let drinkTimestamp = timestamp ?? currentNow
        let currentZone = timeZone()
        let boundary = resolvedBoundaryHour(from: currentSettings)
        let logicalDay = LogicalDay.of(drinkTimestamp, boundaryHour: boundary, timeZone: currentZone)

        let grams: Decimal =
            if let volumeMl, let abvPercent {
                Units.grams(volumeMl: volumeMl, abvPercent: abvPercent)
            } else {
                Units.estimatedGrams(hu: hu)
            }

        let drink = Drink(
            id: UUID(),
            timestamp: drinkTimestamp,
            timeZoneIdentifier: currentZone.identifier,
            logicalDayKey: logicalDay.key,
            presetId: nil,
            name: name,
            huHalfSteps: IntegerStorageConversion.huToHalfSteps(hu),
            volumeMl: volumeMl,
            abvTenths: abvPercent.map(IntegerStorageConversion.abvToTenths),
            centigrams: IntegerStorageConversion.gramsToCentigrams(grams),
            note: nil,
            sourceRaw: source.rawValue,
            healthSyncVersion: 0,
            deletedAt: nil,
            createdAt: currentNow,
            updatedAt: currentNow
        )
        context.insert(drink)
        try context.save()
        return drink
    }

    public func edit(_ drink: Drink, _ edit: DrinkEdit) throws {
        guard drink.deletedAt == nil else {
            throw LogServiceError.drinkIsDeleted
        }

        if let newHU = edit.hu, !Units.isValidHU(newHU) {
            throw LogServiceError.invalidHU
        }

        if let newPresetId = edit.presetId {
            let allPresets = try context.fetch(FetchDescriptor<Preset>())
            if let newPreset = allPresets.first(where: { $0.id == newPresetId }) {
                guard Units.isValidHU(newPreset.hu) else {
                    throw LogServiceError.invalidHU
                }
                drink.presetId = newPreset.id
                drink.name = newPreset.name
                drink.huHalfSteps = newPreset.huHalfSteps
                drink.volumeMl = newPreset.volumeMl
                drink.abvTenths = newPreset.abvTenths
            }
        }

        if let newHU = edit.hu {
            drink.hu = newHU
        }

        if let newName = edit.name {
            drink.name = newName
        }

        switch edit.volumeMl {
        case .unchanged:
            break
        case .set(let volume):
            drink.volumeMl = volume
        case .clear:
            drink.volumeMl = nil
        }

        switch edit.abvPercent {
        case .unchanged:
            break
        case .set(let abv):
            drink.abvPercent = abv
        case .clear:
            drink.abvPercent = nil
        }

        switch edit.note {
        case .unchanged:
            break
        case .set(let note):
            drink.note = note
        case .clear:
            drink.note = nil
        }

        if let volumeMl = drink.volumeMl, let abvPercent = drink.abvPercent {
            drink.grams = Units.grams(volumeMl: volumeMl, abvPercent: abvPercent)
        } else {
            drink.grams = Units.estimatedGrams(hu: drink.hu)
        }

        if let newTimestamp = edit.timestamp {
            let currentSettings = try settings()
            let boundary = resolvedBoundaryHour(from: currentSettings)
            drink.timestamp = newTimestamp
            drink.logicalDay = LogicalDay.of(
                newTimestamp,
                boundaryHour: boundary,
                timeZone: drink.timeZone
            )
        }

        drink.healthSyncVersion += 1
        drink.updatedAt = now()
        try context.save()
    }

    public func delete(_ drink: Drink) throws {
        let currentNow = now()
        drink.deletedAt = currentNow
        drink.updatedAt = currentNow
        try context.save()
    }

    public func undo(_ drink: Drink) throws {
        try delete(drink)
    }

    @discardableResult
    public func purgeTombstones() throws -> Int {
        let cutoff = now().addingTimeInterval(-Self.tombstoneRetentionSeconds)
        let allDrinks = try context.fetch(FetchDescriptor<Drink>())
        var purgedCount = 0

        for drink in allDrinks {
            if let deletedAt = drink.deletedAt, deletedAt < cutoff {
                context.delete(drink)
                purgedCount += 1
            }
        }

        if purgedCount > 0 {
            try context.save()
        }
        return purgedCount
    }

    @discardableResult
    public func dedupeDrinks() throws -> Int {
        let allDrinks = try context.fetch(FetchDescriptor<Drink>())
        var groupedById: [UUID: [Drink]] = [:]
        for drink in allDrinks {
            groupedById[drink.id, default: []].append(drink)
        }

        var removedCount = 0
        for (_, duplicates) in groupedById where duplicates.count > 1 {
            guard var winner = duplicates.first else {
                continue
            }
            for candidate in duplicates.dropFirst() {
                if Self.isPreferredDrink(candidate, over: winner) {
                    winner = candidate
                }
            }

            if let maxSyncedVersion = duplicates.compactMap(\.healthSyncedVersion).max() {
                winner.healthSyncedVersion = maxSyncedVersion
            }

            if let newestTombstone =
                duplicates
                .filter({ $0.deletedAt != nil })
                .max(by: { $0.updatedAt < $1.updatedAt }),
                newestTombstone.updatedAt > winner.updatedAt
            {
                winner.deletedAt = newestTombstone.deletedAt
            }

            for duplicate in duplicates where duplicate.persistentModelID != winner.persistentModelID {
                context.delete(duplicate)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            try context.save()
        }
        return removedCount
    }

    public func drinks(includeDeleted: Bool = false) throws -> [Drink] {
        let allDrinks = try context.fetch(FetchDescriptor<Drink>())
        var winnersById: [UUID: Drink] = [:]
        for drink in allDrinks {
            if let existing = winnersById[drink.id] {
                if Self.isPreferredDrink(drink, over: existing) {
                    winnersById[drink.id] = drink
                }
            } else {
                winnersById[drink.id] = drink
            }
        }

        let deduplicated = Array(winnersById.values)
        let filtered =
            includeDeleted
            ? deduplicated
            : deduplicated.filter { $0.deletedAt == nil }

        return filtered.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    public func snapshots() throws -> [DrinkSnapshot] {
        let allPresets = try context.fetch(FetchDescriptor<Preset>())
        var presetKeyById: [UUID: String] = [:]
        for preset in allPresets {
            if let key = preset.key {
                presetKeyById[preset.id] = key
            }
        }

        let activeDrinks = try drinks(includeDeleted: false)
        return activeDrinks.map { drink in
            let presetKey = drink.presetId.flatMap { presetKeyById[$0] }
            return drink.snapshot(presetKey: presetKey)
        }
    }

    static func isPreferredDrink(_ lhs: Drink, over rhs: Drink) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        if lhs.healthSyncVersion != rhs.healthSyncVersion {
            return lhs.healthSyncVersion > rhs.healthSyncVersion
        }
        let lhsIsTombstone = lhs.deletedAt != nil
        let rhsIsTombstone = rhs.deletedAt != nil
        if lhsIsTombstone != rhsIsTombstone {
            return lhsIsTombstone
        }
        return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
    }

    private func resolvedBoundaryHour(from settings: AppSettings) -> Int {
        (0...23).contains(settings.dayBoundaryHour)
            ? settings.dayBoundaryHour
            : LogicalDay.defaultBoundaryHour
    }
}
