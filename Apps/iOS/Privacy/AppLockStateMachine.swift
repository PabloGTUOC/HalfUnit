import Foundation
import HalfUnitCore
import OSLog
import Observation
import SwiftUI

@MainActor
@Observable
public final class AppLockStateMachine {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit",
        category: "AppLockStateMachine"
    )

    public enum EnableResult: Equatable, Sendable {
        case enabled
        case unavailable
        case failed
    }

    public static let shared = AppLockStateMachine()

    public private(set) var isAppLockEnabled: Bool
    public private(set) var isLocked: Bool
    public private(set) var isShielded: Bool

    public var isContentAccessible: Bool {
        !isShielded
    }

    private let authenticator: any AppLockAuthenticator
    private var wasInBackground: Bool = false

    public init(
        isAppLockEnabled: Bool = false,
        authenticator: any AppLockAuthenticator = SystemAppLockAuthenticator.shared
    ) {
        self.isAppLockEnabled = isAppLockEnabled
        self.authenticator = authenticator
        self.isLocked = isAppLockEnabled
        self.isShielded = isAppLockEnabled
    }

    public func configure(isAppLockEnabled: Bool) {
        self.isAppLockEnabled = isAppLockEnabled
        self.isLocked = isAppLockEnabled
        self.isShielded = isAppLockEnabled
        self.wasInBackground = false
    }

    public func requestEnable(reason: String) async -> EnableResult {
        guard authenticator.canAuthenticate() else {
            return .unavailable
        }
        do {
            let success = try await authenticator.authenticate(localizedReason: reason)
            if success {
                isAppLockEnabled = true
                isLocked = false
                isShielded = false
                wasInBackground = false
                return .enabled
            } else {
                return .failed
            }
        } catch {
            Self.logger.error(
                "Authentication to enable app lock failed: \(error.localizedDescription, privacy: .private)"
            )
            return .failed
        }
    }

    public func disable() {
        isAppLockEnabled = false
        isLocked = false
        isShielded = false
        wasInBackground = false
    }

    public func unlock(reason: String) async -> Bool {
        guard isAppLockEnabled else {
            isLocked = false
            isShielded = false
            return true
        }

        do {
            let success = try await authenticator.authenticate(localizedReason: reason)
            if success {
                isLocked = false
                isShielded = false
                return true
            } else {
                isLocked = true
                isShielded = true
                return false
            }
        } catch {
            Self.logger.error(
                "Unlock authentication failed: \(error.localizedDescription, privacy: .private)"
            )
            isLocked = true
            isShielded = true
            return false
        }
    }

    public func handleScenePhaseChange(to newPhase: ScenePhase) {
        guard isAppLockEnabled else {
            isShielded = false
            isLocked = false
            return
        }

        switch newPhase {
        case .active:
            if wasInBackground {
                wasInBackground = false
                isLocked = true
                isShielded = true
            } else if isLocked {
                isShielded = true
            } else {
                isShielded = false
            }
        case .inactive:
            isShielded = true
        case .background:
            wasInBackground = true
            isLocked = true
            isShielded = true
        @unknown default:
            break
        }
    }
}
