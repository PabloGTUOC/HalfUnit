import Foundation

public struct DrinkTransfer: Codable, Sendable, Equatable {
    public static let currentSchema = 1

    private enum Keys {
        static let schema = "schema"
        static let id = "id"
        static let timestamp = "timestamp"
        static let timeZoneIdentifier = "timeZoneIdentifier"
        static let logicalDayKey = "logicalDayKey"
        static let presetId = "presetId"
        static let name = "name"
        static let huHalfSteps = "huHalfSteps"
        static let volumeMl = "volumeMl"
        static let abvTenths = "abvTenths"
        static let centigrams = "centigrams"
        static let note = "note"
        static let sourceRaw = "sourceRaw"
        static let healthSyncVersion = "healthSyncVersion"
        static let deletedAt = "deletedAt"
        static let createdAt = "createdAt"
        static let updatedAt = "updatedAt"
    }

    public var schema: Int = DrinkTransfer.currentSchema
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

    public var hu: Decimal {
        IntegerStorageConversion.halfStepsToHU(huHalfSteps)
    }

    public var grams: Decimal {
        IntegerStorageConversion.centigramsToGrams(centigrams)
    }

    public var abvPercent: Decimal? {
        abvTenths.map(IntegerStorageConversion.tenthsToABV)
    }

    public init(
        schema: Int = DrinkTransfer.currentSchema,
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
        healthSyncVersion: Int = 0,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.schema = schema
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

    public init(drink: Drink, schema: Int = DrinkTransfer.currentSchema) {
        self.init(
            schema: schema,
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

    public init?(dictionary: [String: Any]) {
        guard
            let schema = Self.extractInt(from: dictionary[Keys.schema]),
            schema == Self.currentSchema,
            let idString = dictionary[Keys.id] as? String,
            let id = UUID(uuidString: idString),
            let timestamp = Self.extractDate(from: dictionary[Keys.timestamp]),
            let timeZoneIdentifier = dictionary[Keys.timeZoneIdentifier] as? String,
            let logicalDayKey = Self.extractInt(from: dictionary[Keys.logicalDayKey]),
            let name = dictionary[Keys.name] as? String,
            let huHalfSteps = Self.extractInt(from: dictionary[Keys.huHalfSteps]),
            let centigrams = Self.extractInt(from: dictionary[Keys.centigrams]),
            let sourceRaw = dictionary[Keys.sourceRaw] as? String,
            let healthSyncVersion = Self.extractInt(from: dictionary[Keys.healthSyncVersion]),
            let createdAt = Self.extractDate(from: dictionary[Keys.createdAt]),
            let updatedAt = Self.extractDate(from: dictionary[Keys.updatedAt])
        else {
            return nil
        }

        let presetId: UUID?
        if let rawPresetId = dictionary[Keys.presetId] {
            guard
                let presetIdString = rawPresetId as? String,
                let parsedPresetId = UUID(uuidString: presetIdString)
            else {
                return nil
            }
            presetId = parsedPresetId
        } else {
            presetId = nil
        }

        let volumeMl: Int?
        if let rawVolumeMl = dictionary[Keys.volumeMl] {
            guard let parsedVolume = Self.extractInt(from: rawVolumeMl) else {
                return nil
            }
            volumeMl = parsedVolume
        } else {
            volumeMl = nil
        }

        let abvTenths: Int?
        if let rawAbvTenths = dictionary[Keys.abvTenths] {
            guard let parsedAbvTenths = Self.extractInt(from: rawAbvTenths) else {
                return nil
            }
            abvTenths = parsedAbvTenths
        } else {
            abvTenths = nil
        }

        let note: String?
        if let rawNote = dictionary[Keys.note] {
            guard let parsedNote = rawNote as? String else {
                return nil
            }
            note = parsedNote
        } else {
            note = nil
        }

        let deletedAt: Date?
        if let rawDeletedAt = dictionary[Keys.deletedAt] {
            guard let parsedDeletedAt = Self.extractDate(from: rawDeletedAt) else {
                return nil
            }
            deletedAt = parsedDeletedAt
        } else {
            deletedAt = nil
        }

        self.init(
            schema: schema,
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

    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            Keys.schema: schema,
            Keys.id: id.uuidString,
            Keys.timestamp: timestamp,
            Keys.timeZoneIdentifier: timeZoneIdentifier,
            Keys.logicalDayKey: logicalDayKey,
            Keys.name: name,
            Keys.huHalfSteps: huHalfSteps,
            Keys.centigrams: centigrams,
            Keys.sourceRaw: sourceRaw,
            Keys.healthSyncVersion: healthSyncVersion,
            Keys.createdAt: createdAt,
            Keys.updatedAt: updatedAt,
        ]

        if let presetId {
            dict[Keys.presetId] = presetId.uuidString
        }
        if let volumeMl {
            dict[Keys.volumeMl] = volumeMl
        }
        if let abvTenths {
            dict[Keys.abvTenths] = abvTenths
        }
        if let note {
            dict[Keys.note] = note
        }
        if let deletedAt {
            dict[Keys.deletedAt] = deletedAt
        }

        return dict
    }

    private static func extractInt(from raw: Any?) -> Int? {
        if let intValue = raw as? Int {
            return intValue
        }
        if let number = raw as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            let doubleValue = number.doubleValue
            let intValue = number.intValue
            if Double(intValue) == doubleValue {
                return intValue
            }
        }
        return nil
    }

    private static func extractDate(from raw: Any?) -> Date? {
        if let date = raw as? Date {
            return date
        }
        if let timeInterval = raw as? TimeInterval {
            return Date(timeIntervalSince1970: timeInterval)
        }
        return nil
    }
}
