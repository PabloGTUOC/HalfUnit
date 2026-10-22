import Foundation
import HalfUnitCore

final class FakeHealthStoreClient: HealthStoreClient, @unchecked Sendable {
    struct Failure: Error, Equatable, Sendable {
        let reason: String

        init(_ reason: String = "Simulated HealthKit error") {
            self.reason = reason
        }
    }

    var isAvailable: Bool
    var authorization: HealthWriteAuthorization
    var authorizationAfterRequest: HealthWriteAuthorization?
    var requestAuthorizationError: (any Error)?
    var saveError: (any Error)?
    var deleteError: (any Error)?

    private(set) var requestAuthorizationCallCount = 0
    private(set) var savedBatches: [[HealthDrinkSample]] = []
    private(set) var deletedIdentifierBatches: [[String]] = []

    init(
        isAvailable: Bool = true,
        authorization: HealthWriteAuthorization = .authorized
    ) {
        self.isAvailable = isAvailable
        self.authorization = authorization
    }

    func writeAuthorization() async -> HealthWriteAuthorization {
        guard isAvailable else {
            return .unavailable
        }
        return authorization
    }

    func requestWriteAuthorization() async throws {
        requestAuthorizationCallCount += 1
        if let error = requestAuthorizationError {
            throw error
        }
        if let next = authorizationAfterRequest {
            authorization = next
        }
    }

    func save(_ samples: [HealthDrinkSample]) async throws {
        if let error = saveError {
            throw error
        }
        savedBatches.append(samples)
    }

    func deleteSamples(withSyncIdentifiers ids: [String]) async throws {
        if let error = deleteError {
            throw error
        }
        deletedIdentifierBatches.append(ids)
    }
}
