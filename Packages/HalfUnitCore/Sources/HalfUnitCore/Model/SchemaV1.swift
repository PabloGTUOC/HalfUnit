import Foundation
import SwiftData

public typealias Drink = SchemaV1.Drink
public typealias Preset = SchemaV1.Preset
public typealias AppSettings = SchemaV1.AppSettings

public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [Drink.self, Preset.self, AppSettings.self]
    }

    @Model
    public final class Drink {
        public var id: UUID = UUID()
        public var timestamp: Date = Date.distantPast
        public var timeZoneIdentifier: String = "UTC"
        public var logicalDayKey: Int = 19_700_101
        public var presetId: UUID? = nil
        public var name: String = ""
        public var huHalfSteps: Int = 1
        public var volumeMl: Int? = nil
        public var abvTenths: Int? = nil
        public var centigrams: Int = 0
        public var note: String? = nil
        public var sourceRaw: String = DrinkSource.phone.rawValue
        public var healthSyncVersion: Int = 0
        public var deletedAt: Date? = nil
        public var createdAt: Date = Date.distantPast
        public var updatedAt: Date = Date.distantPast

        public init(
            id: UUID = UUID(),
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
            sourceRaw: String = DrinkSource.phone.rawValue,
            healthSyncVersion: Int = 0,
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
    }

    @Model
    public final class Preset {
        public var id: UUID = UUID()
        public var key: String? = nil
        public var name: String = ""
        public var symbolName: String = ""
        public var huHalfSteps: Int = 1
        public var volumeMl: Int = 0
        public var abvTenths: Int = 0
        public var sortOrder: Int = 0
        public var isHidden: Bool = false
        public var updatedAt: Date = Date.distantPast

        public init(
            id: UUID = UUID(),
            key: String? = nil,
            name: String,
            symbolName: String,
            huHalfSteps: Int,
            volumeMl: Int,
            abvTenths: Int,
            sortOrder: Int = 0,
            isHidden: Bool = false,
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
    }

    @Model
    public final class AppSettings {
        public var dayBoundaryHour: Int = LogicalDay.defaultBoundaryHour
        public var displayUnitRaw: String = DisplayUnit.hu.rawValue
        public var firstUseDayKey: Int = 19_700_101
        public var healthReadEnabled: Bool = false
        public var remindersEnabled: Bool = false
        public var reminderMinutes: Int? = nil
        public var appLockEnabled: Bool = false
        public var updatedAt: Date = Date.distantPast

        public init(
            dayBoundaryHour: Int = LogicalDay.defaultBoundaryHour,
            displayUnitRaw: String = DisplayUnit.hu.rawValue,
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
    }
}
