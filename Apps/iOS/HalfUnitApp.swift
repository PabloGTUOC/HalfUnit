import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI

@main
struct HalfUnitApp: App {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit", category: "Persistence")
    static let isHealthSyncEnabled = true

    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let logService: LogService
    private let healthSync: HealthSync
    private let dayBoundaryScheduler: DayBoundaryScheduler

    init() {
        let container = Self.makeModelContainer()
        let service = LogService(
            context: container.mainContext,
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )
        let health = HealthSync(
            context: container.mainContext,
            client: HealthKitStoreClient.shared,
            isEnabled: { Self.isHealthSyncEnabled }
        )
        let scheduler = DayBoundaryScheduler(
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )

        do {
            try service.seedDefaultPresetsIfNeeded()
        } catch {
            Self.logger.error("Failed to seed default presets: \(error.localizedDescription, privacy: .private)")
        }

        self.modelContainer = container
        self.logService = service
        self.healthSync = health
        self.dayBoundaryScheduler = scheduler

        Task { @MainActor in
            await Self.reconcileAndPurgeTombstones(logService: service, healthSync: health)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                logService: logService,
                healthSync: healthSync,
                dayBoundaryScheduler: dayBoundaryScheduler
            )
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            Task { @MainActor in
                await Self.reconcileAndPurgeTombstones(logService: logService, healthSync: healthSync)
            }
        }
    }

    @MainActor
    static func reconcileAndPurgeTombstones(
        logService: LogService,
        healthSync: HealthSync
    ) async {
        await reconcileHealth(healthSync: healthSync)
        do {
            _ = try logService.purgeTombstones()
        } catch {
            logger.error("Failed to purge tombstones: \(error.localizedDescription, privacy: .private)")
        }
    }

    @MainActor
    static func reconcileHealth(healthSync: HealthSync) async {
        let status = await healthSync.reconcile()
        if case .failed(let reason) = status {
            logger.error("Health sync reconcile failed: \(reason, privacy: .public)")
        }
    }

    private static func makeModelContainer() -> ModelContainer {
        let appGroupIdentifier = Bundle.main.object(forInfoDictionaryKey: "HalfUnitAppGroup") as? String
        let cloudKitContainer = Bundle.main.object(forInfoDictionaryKey: "HalfUnitCloudKitContainer") as? String

        let storeURL: URL? =
            if let appGroupIdentifier,
                let groupURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: appGroupIdentifier
                )
            {
                groupURL.appending(path: "HalfUnit.store")
            } else {
                nil
            }

        do {
            return try ModelContainerFactory.make(
                storeURL: storeURL,
                cloudKitContainerIdentifier: cloudKitContainer,
                inMemory: false
            )
        } catch {
            logger.notice(
                "CloudKit container init failed; falling back to local store: \(error.localizedDescription, privacy: .public)"
            )
            do {
                return try ModelContainerFactory.make(
                    storeURL: storeURL,
                    cloudKitContainerIdentifier: nil,
                    inMemory: false
                )
            } catch {
                logger.error(
                    "Local store init failed; falling back to in-memory store: \(error.localizedDescription, privacy: .public)"
                )
                do {
                    return try ModelContainerFactory.make(inMemory: true)
                } catch {
                    preconditionFailure("Unable to create in-memory ModelContainer")
                }
            }
        }
    }
}
