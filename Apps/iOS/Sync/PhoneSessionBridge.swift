import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import UIKit
import WatchConnectivity

@MainActor
protocol PhoneSessionTransport: AnyObject {
    var isSupported: Bool { get }
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    func activate(delegate: any WCSessionDelegate)
    func updateApplicationContext(_ applicationContext: [String: Any]) throws
}

@MainActor
final class WCSessionPhoneTransport: PhoneSessionTransport {
    var isSupported: Bool {
        WCSession.isSupported()
    }

    var isPaired: Bool {
        guard WCSession.isSupported() else {
            return false
        }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired
    }

    var isWatchAppInstalled: Bool {
        guard WCSession.isSupported() else {
            return false
        }
        let session = WCSession.default
        return session.activationState == .activated && session.isWatchAppInstalled
    }

    func activate(delegate: any WCSessionDelegate) {
        guard WCSession.isSupported() else {
            return
        }
        let session = WCSession.default
        session.delegate = delegate
        session.activate()
    }

    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
        guard WCSession.isSupported() else {
            return
        }
        try WCSession.default.updateApplicationContext(applicationContext)
    }
}

@MainActor
final class PhoneSessionBridge: NSObject {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit",
        category: "PhoneSessionBridge"
    )

    private let context: ModelContext
    private let logService: LogService
    private let healthSync: HealthSync
    private let now: @Sendable () -> Date
    private let dayBoundaryScheduler: DayBoundaryScheduler?
    private let transport: any PhoneSessionTransport

    private var isSuppressingSaveObserver = false
    nonisolated(unsafe) private var observerTokens: [any NSObjectProtocol] = []
    nonisolated(unsafe) private var boundaryTask: Task<Void, Never>?

    deinit {
        boundaryTask?.cancel()
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
        }
    }

    init(
        context: ModelContext,
        logService: LogService,
        healthSync: HealthSync,
        now: @escaping @Sendable () -> Date = Date.init,
        dayBoundaryScheduler: DayBoundaryScheduler? = nil,
        transport: any PhoneSessionTransport = WCSessionPhoneTransport(),
        activateImmediately: Bool = true
    ) {
        self.context = context
        self.logService = logService
        self.healthSync = healthSync
        self.now = now
        self.dayBoundaryScheduler = dayBoundaryScheduler
        self.transport = transport
        super.init()

        registerObservers()
        startDayBoundaryTaskIfNeeded()
        if activateImmediately {
            activate()
        }
    }

    func activate() {
        guard transport.isSupported else {
            return
        }
        transport.activate(delegate: self)
    }

    func handleReceivedUserInfo(_ userInfo: [String: Any]) async {
        guard let transfer = DrinkTransfer(dictionary: userInfo) else {
            return
        }
        await handleReceivedTransfer(transfer)
    }

    func handleReceivedTransfer(_ transfer: DrinkTransfer) async {
        isSuppressingSaveObserver = true
        defer {
            isSuppressingSaveObserver = false
        }

        do {
            let applier = DrinkTransferApplier(context: context)
            _ = try applier.apply(transfer)
            _ = try logService.dedupeDrinks()
        } catch {
            Self.logger.error("Failed to apply incoming watch drink transfer")
        }

        await HalfUnitApp.reconcileHealth(healthSync: healthSync)
        pushCurrentStateContext()
    }

    func performWithoutSaveObserver<T>(_ body: () throws -> T) rethrows -> T {
        let previous = isSuppressingSaveObserver
        isSuppressingSaveObserver = true
        defer {
            isSuppressingSaveObserver = previous
        }
        return try body()
    }

    func pushCurrentStateContext() {
        guard transport.isSupported, transport.isPaired, transport.isWatchAppInstalled else {
            return
        }

        do {
            let stateContext = try WatchStateContext.make(from: logService, generatedAt: now())
            try transport.updateApplicationContext(stateContext.toDictionary())
        } catch {
            Self.logger.error("Failed to push watch application context")
        }
    }

    private func registerObservers() {
        let saveToken = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isSuppressingSaveObserver else {
                    return
                }
                self.pushCurrentStateContext()
            }
        }
        observerTokens.append(saveToken)

        let notificationNames: [Notification.Name] = [
            .NSCalendarDayChanged,
            UIApplication.significantTimeChangeNotification,
            .NSSystemTimeZoneDidChange,
        ]
        for name in notificationNames {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.pushCurrentStateContext()
                    self?.startDayBoundaryTaskIfNeeded()
                }
            }
            observerTokens.append(token)
        }
    }

    private func startDayBoundaryTaskIfNeeded() {
        boundaryTask?.cancel()
        guard let scheduler = dayBoundaryScheduler else {
            return
        }

        boundaryTask = Task { @MainActor [weak self] in
            var referenceDate = scheduler.now()
            while !Task.isCancelled {
                let boundaryHour =
                    (try? self?.logService.settings().dayBoundaryHour)
                    ?? LogicalDay.defaultBoundaryHour
                let nextBoundary = scheduler.nextBoundaryDate(
                    after: referenceDate,
                    boundaryHour: boundaryHour
                )
                let delay = max(0.05, nextBoundary.timeIntervalSince(scheduler.now()))
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else {
                    return
                }
                self.pushCurrentStateContext()
                referenceDate = max(scheduler.now(), nextBoundary)
            }
        }
    }
}

extension PhoneSessionBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if error != nil {
            Task { @MainActor in
                Self.logger.error("WCSession activation failed on phone")
            }
            return
        }
        if activationState == .activated {
            Task { @MainActor [weak self] in
                self?.pushCurrentStateContext()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.pushCurrentStateContext()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        guard let transfer = DrinkTransfer(dictionary: userInfo) else {
            return
        }
        Task { @MainActor [weak self] in
            await self?.handleReceivedTransfer(transfer)
        }
    }
}
