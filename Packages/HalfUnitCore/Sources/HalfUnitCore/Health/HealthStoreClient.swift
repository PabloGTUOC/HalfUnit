import Foundation

public struct HealthDrinkSample: Sendable, Equatable {
    public let syncIdentifier: String
    public let syncVersion: Int
    public let date: Date
    public let standardDrinks: Decimal
    public let presetKey: String?
    public let hu: Decimal
    public let grams: Decimal
    public let volumeMl: Int?
    public let abvPercent: Decimal?

    public init(
        syncIdentifier: String,
        syncVersion: Int,
        date: Date,
        standardDrinks: Decimal,
        presetKey: String?,
        hu: Decimal,
        grams: Decimal,
        volumeMl: Int?,
        abvPercent: Decimal?
    ) {
        self.syncIdentifier = syncIdentifier
        self.syncVersion = syncVersion
        self.date = date
        self.standardDrinks = standardDrinks
        self.presetKey = presetKey
        self.hu = hu
        self.grams = grams
        self.volumeMl = volumeMl
        self.abvPercent = abvPercent
    }
}

public enum HealthWriteAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case unavailable
}

public protocol HealthStoreClient: Sendable {
    var isAvailable: Bool { get }
    func writeAuthorization() async -> HealthWriteAuthorization
    func requestWriteAuthorization() async throws
    func save(_ samples: [HealthDrinkSample]) async throws
    func deleteSamples(withSyncIdentifiers ids: [String]) async throws
}
