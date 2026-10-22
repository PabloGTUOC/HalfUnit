import Foundation
import SwiftData

/// Synchronises `Drink` records in the local SwiftData store to Apple Health on iOS.
///
/// Tombstone ordering note: `LogService.purgeTombstones()` removes tombstones only once they are
/// older than 30 days. The iOS app must call `reconcile()` on launch and when returning to the
/// foreground (before or alongside `purgeTombstones()`) so that deleted drinks are removed from
/// Apple Health well before their 30-day retention window expires.
@MainActor
public final class HealthSync {
    public enum Status: Sendable, Equatable {
        case disabled
        case unavailable
        case notAuthorized
        case upToDate
        case failed(String)
    }

    private let context: ModelContext
    private let client: any HealthStoreClient
    private let isEnabled: @MainActor () -> Bool

    public private(set) var lastStatus: Status

    public init(
        context: ModelContext,
        client: any HealthStoreClient,
        isEnabled: @escaping @MainActor () -> Bool
    ) {
        self.context = context
        self.client = client
        self.isEnabled = isEnabled
        if !isEnabled() {
            self.lastStatus = .disabled
        } else if !client.isAvailable {
            self.lastStatus = .unavailable
        } else {
            self.lastStatus = .notAuthorized
        }
    }

    public func requestAuthorization() async -> HealthWriteAuthorization {
        guard client.isAvailable else {
            return .unavailable
        }
        try? await client.requestWriteAuthorization()
        return await client.writeAuthorization()
    }

    @discardableResult
    public func reconcile() async -> Status {
        guard isEnabled() else {
            lastStatus = .disabled
            return .disabled
        }

        guard client.isAvailable else {
            lastStatus = .unavailable
            return .unavailable
        }

        let authorization = await client.writeAuthorization()
        if authorization == .unavailable {
            lastStatus = .unavailable
            return .unavailable
        }
        guard authorization == .authorized else {
            lastStatus = .notAuthorized
            return .notAuthorized
        }

        do {
            let allDrinks = try context.fetch(FetchDescriptor<Drink>())
            let allPresets = try context.fetch(FetchDescriptor<Preset>())

            var presetKeyById: [UUID: String] = [:]
            for preset in allPresets {
                if let key = preset.key {
                    presetKeyById[preset.id] = key
                }
            }

            let pendingCandidates =
                allDrinks
                .filter { $0.deletedAt == nil && $0.healthSyncedVersion != $0.healthSyncVersion }
            let pendingLiveDrinks = Self.selectPendingLiveDrinks(from: pendingCandidates)
            if !pendingLiveDrinks.isEmpty {
                let samples = pendingLiveDrinks.map { drink in
                    let presetKey = drink.presetId.flatMap { presetKeyById[$0] }
                    return HealthDrinkSample(
                        syncIdentifier: drink.id.uuidString,
                        syncVersion: drink.healthSyncVersion + 1,
                        date: drink.timestamp,
                        standardDrinks: Units.standardDrinks(grams: drink.grams),
                        presetKey: presetKey,
                        hu: drink.hu,
                        grams: drink.grams,
                        volumeMl: drink.volumeMl,
                        abvPercent: drink.abvPercent
                    )
                }

                try await client.save(samples)
                for drink in pendingCandidates {
                    drink.healthSyncedVersion = drink.healthSyncVersion
                }
                try context.save()
            }

            let pendingTombstones = Self.selectPendingTombstones(from: allDrinks)
            if !pendingTombstones.isEmpty {
                var seenIds: Set<String> = []
                var idsToDelete: [String] = []
                for drink in pendingTombstones {
                    let syncId = drink.id.uuidString
                    if seenIds.insert(syncId).inserted {
                        idsToDelete.append(syncId)
                    }
                }

                try await client.deleteSamples(withSyncIdentifiers: idsToDelete)
                for drink in pendingTombstones {
                    drink.healthSyncedVersion = nil
                }
                try context.save()
            }

            lastStatus = .upToDate
            return .upToDate
        } catch {
            let status = Status.failed("Health sync failed (\(type(of: error)))")
            lastStatus = status
            return status
        }
    }

    private static func selectPendingLiveDrinks(from drinks: [Drink]) -> [Drink] {
        let candidates =
            drinks
            .filter { $0.deletedAt == nil && $0.healthSyncedVersion != $0.healthSyncVersion }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp < rhs.timestamp
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        var chosenById: [UUID: Drink] = [:]
        var orderedIds: [UUID] = []
        for drink in candidates {
            if let existing = chosenById[drink.id] {
                if drink.updatedAt > existing.updatedAt
                    || (drink.updatedAt == existing.updatedAt
                        && drink.healthSyncVersion > existing.healthSyncVersion)
                {
                    chosenById[drink.id] = drink
                }
            } else {
                chosenById[drink.id] = drink
                orderedIds.append(drink.id)
            }
        }

        return orderedIds.compactMap { chosenById[$0] }
    }

    private static func selectPendingTombstones(from drinks: [Drink]) -> [Drink] {
        drinks
            .filter { $0.deletedAt != nil && $0.healthSyncedVersion != nil }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return lhs.timestamp < rhs.timestamp
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }
}
