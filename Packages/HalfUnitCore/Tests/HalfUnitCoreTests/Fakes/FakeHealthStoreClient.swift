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

    var shouldSuspendNextSave = false
    private var saveSuspendedContinuation: CheckedContinuation<Void, Never>?
    private var saveResumeContinuation: CheckedContinuation<Void, Never>?

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

    func waitForSaveToSuspend() async {
        if saveResumeContinuation != nil {
            return
        }
        await withCheckedContinuation { continuation in
            saveSuspendedContinuation = continuation
        }
    }

    func resumeSuspendedSave() {
        let continuation = saveResumeContinuation
        saveResumeContinuation = nil
        continuation?.resume()
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
        if shouldSuspendNextSave {
            shouldSuspendNextSave = false
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                saveResumeContinuation = continuation
                if let waiting = saveSuspendedContinuation {
                    saveSuspendedContinuation = nil
                    waiting.resume()
                }
            }
        }
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
