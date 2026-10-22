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

    init() {
        let container = Self.makeModelContainer()
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

        self.modelContainer = container
        self.logService = service
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
