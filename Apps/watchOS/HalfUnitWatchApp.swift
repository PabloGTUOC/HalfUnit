import Foundation
import HalfUnitCore
import OSLog
import SwiftData
import SwiftUI

@main
struct HalfUnitWatchApp: App {
    private static let logger = Logger(subsystem: "es.opinasdeque.halfunit.watchkitapp", category: "Persistence")

    private let modelContainer: ModelContainer
    private let logService: LogService
    private let watchSessionBridge: WatchSessionBridge

    init() {
        let container = SharedStore.makeModelContainer()
        let service = LogService(
            context: container.mainContext,
            now: Date.init,
            timeZone: { TimeZone.autoupdatingCurrent }
        )

        do {
            try service.seedDefaultPresetsIfNeeded()
        } catch {
            Self.logger.error("Failed to seed default presets: \(error.localizedDescription, privacy: .public)")
        }

        let sessionBridge = WatchSessionBridge(
            context: container.mainContext,
            logService: service
        )

        self.modelContainer = container
        self.logService = service
        self.watchSessionBridge = sessionBridge
    }

    var body: some Scene {
        WindowGroup {
            WatchLoggerView(
                logService: logService,
                now: Date.init,
                timeZone: { TimeZone.autoupdatingCurrent }
            )
        }
        .modelContainer(modelContainer)
    }
}
