import Foundation
import LocalAuthentication

public protocol AppLockAuthenticator: Sendable {
    func canAuthenticate() -> Bool
    func authenticate(localizedReason: String) async throws -> Bool
}

public final class SystemAppLockAuthenticator: AppLockAuthenticator, @unchecked Sendable {
    public static let shared = SystemAppLockAuthenticator()

    public init() {}

    public func canAuthenticate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    public func authenticate(localizedReason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: localizedReason
        )
    }
}
