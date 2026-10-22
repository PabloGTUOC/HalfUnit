#if canImport(HealthKit) && os(iOS)
    import Foundation
    import HealthKit

    public final class HealthKitStoreClient: HealthStoreClient {
        public static let shared = HealthKitStoreClient()

        public static let presetKeyMetadataKey = "HalfUnitPresetKey"
        public static let huMetadataKey = "HalfUnitHU"
        public static let gramsMetadataKey = "HalfUnitGrams"
        public static let volumeMlMetadataKey = "HalfUnitVolumeMl"
        public static let abvMetadataKey = "HalfUnitABV"

        private static let sharedStore = HKHealthStore()
        private static let alcoholicBeveragesType = HKQuantityType(.numberOfAlcoholicBeverages)

        private let store: HKHealthStore

        public init() {
            self.store = Self.sharedStore
        }

        public init(store: HKHealthStore) {
            self.store = store
        }

        public var isAvailable: Bool {
            HKHealthStore.isHealthDataAvailable()
        }

        public func writeAuthorization() async -> HealthWriteAuthorization {
            guard isAvailable else {
                return .unavailable
            }
            switch store.authorizationStatus(for: Self.alcoholicBeveragesType) {
            case .notDetermined:
                return .notDetermined
            case .sharingDenied:
                return .denied
            case .sharingAuthorized:
                return .authorized
            @unknown default:
                return .denied
            }
        }

        public func requestWriteAuthorization() async throws {
            guard isAvailable else {
                return
            }
            try await store.requestAuthorization(toShare: [Self.alcoholicBeveragesType], read: [])
        }

        public func save(_ samples: [HealthDrinkSample]) async throws {
            guard !samples.isEmpty else {
                return
            }
            let quantitySamples = samples.map(Self.makeQuantitySample)
            try await store.save(quantitySamples)
        }

        public func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
            guard !ids.isEmpty else {
                return
            }
            let predicate = HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: ids
            )
            _ = try await store.deleteObjects(of: Self.alcoholicBeveragesType, predicate: predicate)
        }

        private static func makeQuantitySample(from sample: HealthDrinkSample) -> HKQuantitySample {
            let standardDrinksDouble = NSDecimalNumber(decimal: sample.standardDrinks).doubleValue
            let quantity = HKQuantity(unit: .count(), doubleValue: standardDrinksDouble)

            var metadata: [String: Any] = [
                HKMetadataKeySyncIdentifier: sample.syncIdentifier,
                HKMetadataKeySyncVersion: sample.syncVersion,
                huMetadataKey: NSDecimalNumber(decimal: sample.hu).stringValue,
                gramsMetadataKey: NSDecimalNumber(decimal: sample.grams).stringValue,
            ]

            if let presetKey = sample.presetKey {
                metadata[presetKeyMetadataKey] = presetKey
            }
            if let volumeMl = sample.volumeMl {
                metadata[volumeMlMetadataKey] = volumeMl
            }
            if let abvPercent = sample.abvPercent {
                metadata[abvMetadataKey] = NSDecimalNumber(decimal: abvPercent).stringValue
            }

            return HKQuantitySample(
                type: alcoholicBeveragesType,
                quantity: quantity,
                start: sample.date,
                end: sample.date,
                metadata: metadata
            )
        }
    }
#endif
