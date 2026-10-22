import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import WatchConnectivity
import WidgetKit

@MainActor
protocol WatchSessionTransport: AnyObject {
    var isSupported: Bool { get }
    var receivedApplicationContextDictionary: [String: Any] { get }
    func activate(delegate: any WCSessionDelegate)
    func transferUserInfo(_ userInfo: [String: Any])
}

@MainActor
final class WCSessionWatchTransport: WatchSessionTransport {
    var isSupported: Bool {
        WCSession.isSupported()
    }

    var receivedApplicationContextDictionary: [String: Any] {
        guard WCSession.isSupported() else {
            return [:]
        }
        return WCSession.default.receivedApplicationContext
    }

    func activate(delegate: any WCSessionDelegate) {
        guard WCSession.isSupported() else {
            return
        }
        let session = WCSession.default
        session.delegate = delegate
        session.activate()
    }

    func transferUserInfo(_ userInfo: [String: Any]) {
        guard WCSession.isSupported() else {
            return
        }
        _ = WCSession.default.transferUserInfo(userInfo)
    }
}

@MainActor
final class WatchSessionBridge: NSObject {
    private static let logger = Logger(
        subsystem: "es.opinasdeque.halfunit.watchkitapp",
        category: "WatchSessionBridge"
    )

    private let context: ModelContext
    private let logService: LogService
    private let transport: any WatchSessionTransport
    private var lastTransferredUpdatedAtById: [UUID: Date] = [:]
    nonisolated(unsafe) private var didSaveObserver: (any NSObjectProtocol)?

    private(set) var latestStateContext: WatchStateContext?

    deinit {
        if let didSaveObserver {
            NotificationCenter.default.removeObserver(didSaveObserver)
        }
    }

    init(
        context: ModelContext,
        logService: LogService,
        transport: any WatchSessionTransport = WCSessionWatchTransport(),
        activateImmediately: Bool = true
    ) {
        self.context = context
        self.logService = logService
        self.transport = transport
        super.init()

        recordBaselineDrinks()
        registerObservers()
        if activateImmediately {
            activate()
        }
    }

    func activate() {
        guard transport.isSupported else {
            return
        }
        transport.activate(delegate: self)
        if let initial = WatchStateContext(dictionary: transport.receivedApplicationContextDictionary) {
            latestStateContext = initial
        }
    }

    func send(drink: Drink) {
        lastTransferredUpdatedAtById[drink.id] = drink.updatedAt
        send(transfer: DrinkTransfer(drink: drink))
    }

    func send(transfer: DrinkTransfer) {
        guard transport.isSupported else {
            return
        }
        transport.transferUserInfo(transfer.toDictionary())
    }

    func transferModifiedDrinks() {
        do {
            let currentDrinks = try logService.drinks(includeDeleted: true)
            for drink in currentDrinks {
                if let previousUpdatedAt = lastTransferredUpdatedAtById[drink.id] {
                    if drink.updatedAt > previousUpdatedAt {
                        send(drink: drink)
                    }
                } else {
                    send(drink: drink)
                }
            }
        } catch {
            Self.logger.error("Failed to inspect watch drinks for transfer")
        }
    }

    func handleReceivedStateContext(_ stateContext: WatchStateContext) {
        latestStateContext = stateContext
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Exposes the remote `WatchStateContext` only when the watch's own store has no drink data yet,
    /// keeping the watch store as the source of truth.
    func fallbackStateContextIfStoreEmpty() -> WatchStateContext? {
        do {
            let existingDrinks = try context.fetch(FetchDescriptor<Drink>())
            guard existingDrinks.isEmpty else {
                return nil
            }
            return latestStateContext
        } catch {
            return nil
        }
    }

    private func recordBaselineDrinks() {
        guard let existingDrinks = try? logService.drinks(includeDeleted: true) else {
            return
        }
        for drink in existingDrinks {
            lastTransferredUpdatedAtById[drink.id] = drink.updatedAt
        }
    }

    private func registerObservers() {
        didSaveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.transferModifiedDrinks()
            }
        }
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if error != nil {
            Task { @MainActor in
                Self.logger.error("WCSession activation failed on watch")
            }
            return
        }
        let receivedContext = WatchStateContext(dictionary: session.receivedApplicationContext)
        if let receivedContext {
            Task { @MainActor [weak self] in
                self?.handleReceivedStateContext(receivedContext)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let stateContext = WatchStateContext(dictionary: applicationContext) else {
            return
        }
        Task { @MainActor [weak self] in
            self?.handleReceivedStateContext(stateContext)
        }
    }
}
