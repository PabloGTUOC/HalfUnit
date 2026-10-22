import Foundation
import SwiftData

@MainActor
public struct DrinkTransferApplier {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func apply(dictionary: [String: Any]) throws -> Bool {
        guard let transfer = DrinkTransfer(dictionary: dictionary) else {
            return false
        }
        return try apply(transfer)
    }

    @discardableResult
    public func apply(_ transfer: DrinkTransfer) throws -> Bool {
        guard transfer.schema == DrinkTransfer.currentSchema else {
            return false
        }

        let allDrinks = try context.fetch(FetchDescriptor<Drink>())
        let matchingDrinks = allDrinks.filter { $0.id == transfer.id }

        if var existing = matchingDrinks.first {
            for candidate in matchingDrinks.dropFirst() {
                if LogService.isPreferredDrink(candidate, over: existing) {
                    existing = candidate
                }
            }

            guard transfer.updatedAt > existing.updatedAt else {
                return false
            }

            existing.timestamp = transfer.timestamp
            existing.timeZoneIdentifier = transfer.timeZoneIdentifier
            existing.logicalDayKey = transfer.logicalDayKey
            existing.presetId = transfer.presetId
            existing.name = transfer.name
            existing.huHalfSteps = transfer.huHalfSteps
            existing.volumeMl = transfer.volumeMl
            existing.abvTenths = transfer.abvTenths
            existing.centigrams = transfer.centigrams
            existing.note = transfer.note
            existing.sourceRaw = transfer.sourceRaw
            existing.healthSyncVersion = transfer.healthSyncVersion
            existing.deletedAt = transfer.deletedAt
            existing.createdAt = transfer.createdAt
            existing.updatedAt = transfer.updatedAt
            try context.save()
            return true
        }

        let inserted = Drink(
            id: transfer.id,
            timestamp: transfer.timestamp,
            timeZoneIdentifier: transfer.timeZoneIdentifier,
            logicalDayKey: transfer.logicalDayKey,
            presetId: transfer.presetId,
            name: transfer.name,
            huHalfSteps: transfer.huHalfSteps,
            volumeMl: transfer.volumeMl,
            abvTenths: transfer.abvTenths,
            centigrams: transfer.centigrams,
            note: transfer.note,
            sourceRaw: transfer.sourceRaw,
            healthSyncVersion: transfer.healthSyncVersion,
            healthSyncedVersion: nil,
            deletedAt: transfer.deletedAt,
            createdAt: transfer.createdAt,
            updatedAt: transfer.updatedAt
        )
        context.insert(inserted)
        try context.save()
        return true
    }
}
